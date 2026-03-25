//
//  Test.Trait.Scope.Provider.timed.swift
//  swift-tests
//
//  Scope provider for timed benchmark execution.
//

import Clocks
import Memory
import File_System
import IO

extension Test.Trait.Scope.Provider {
    /// Scope provider for timed benchmark measurement.
    public static var timed: Self {
        Self(
            id: "timed",
            priority: 50,
            shouldActivate: { $0[Test.Trait.Timed.self] != nil },
            provideScope: _timedScope
        )
    }

    @Sendable
    private static func _timedScope(
        _ entry: Test.Plan.Entry,
        _ traits: Test.Trait.Collection,
        _ operation: @Sendable () async throws(Error) -> Void
    ) async throws(Error) {
        let config = traits[Test.Trait.Timed.self]!

        // Warmup iterations
        for _ in 0..<config.iteration.warmup {
            try await operation()
        }

        // Measured iterations
        var durations: [Duration] = []
        durations.reserveCapacity(config.iteration.count)
        var allocationStats: [Memory.Allocation.Statistics]? = config.evaluation.trackAllocations ? [] : nil

        for _ in 0..<config.iteration.count {
            let before = config.evaluation.trackAllocations
                ? Memory.Allocation.Statistics.capture()
                : nil
            let start = Clock_Primitives.Clock.Continuous.now
            try await operation()
            durations.append(Clock_Primitives.Clock.Continuous.now - start)
            if let before {
                let after = Memory.Allocation.Statistics.capture()
                allocationStats?.append(Memory.Allocation.Statistics.delta(from: before, to: after))
            }
        }

        let testName = entry.id.fullyQualifiedName
        _diagLog(testName, "ITERATIONS_DONE")

        let measurement = Test.Benchmark.Measurement(durations: durations)

        // Capture environment (needed for both diagnostics and baseline keying)
        let environment = Test.Environment.capture()
        _diagLog(testName, "ENV_CAPTURED")

        // Shared root for baselines and history
        let root = Tests.Baseline.Storage.root()

        // Baseline comparison (if configured)
        var storedBaseline: Test.Benchmark.Measurement? = nil
        var comparison: Tests.Comparison? = nil

        if config.evaluation.baselineTolerance != nil {
            let baselinePath = Tests.Baseline.Storage.path(
                root: root,
                testID: entry.id,
                fingerprint: environment.fingerprint
            )
            let recording = Tests.Baseline.Recording.current

            // Try to load existing baseline
            do {
                storedBaseline = try await Tests.Baseline.Storage.load(at: baselinePath)
            } catch {
                _diagLog(testName, "BASELINE_LOAD_ERROR: \(error)")
            }

            if let baseline = storedBaseline {
                // Build comparison
                comparison = Tests.Comparison(
                    name: entry.id.name,
                    current: measurement,
                    baseline: baseline,
                    metric: config.evaluation.metric
                )

                // Overwrite baseline if recording mode is .all
                if recording == .all {
                    do {
                        try await Tests.Baseline.Storage.save(measurement, to: baselinePath)
                    } catch {
                        _diagLog(testName, "BASELINE_SAVE_ERROR: \(error)")
                    }
                }
            } else {
                // No baseline exists
                switch recording {
                case .normal, .all:
                    // Save current measurement as the new baseline
                    do {
                        try await Tests.Baseline.Storage.save(measurement, to: baselinePath)
                    } catch {
                        _diagLog(testName, "BASELINE_SAVE_ERROR: \(error)")
                    }
                case .never:
                    throw .baselineMissing(
                        test: entry.id.name,
                        path: Swift.String(baselinePath)
                    )
                }
            }
        }

        _diagLog(testName, "BASELINE_DONE")

        // Build diagnostic
        let cv = measurement.coefficientOfVariation
        let mad = measurement.medianAbsoluteDeviation
        let outliers = measurement.outlierCount()
        let trend = Test.Benchmark.Trend.mannKendall(measurement.durations)

        let metricValue = config.evaluation.metric.extract(from: measurement)
        let exceeded = config.evaluation.threshold.map { metricValue > $0 } ?? false
        let factor: Double? = if let threshold = config.evaluation.threshold, exceeded {
            metricValue.inSeconds / threshold.inSeconds
        } else {
            nil
        }

        // Run history: append record and analyze cross-run trend
        var historyAnalysis: Tests.History.Analysis? = nil

        if Tests.History.Storage.isEnabled {
            let record = Tests.History.Record(
                timestamp: _epochSeconds(),
                testID: entry.id,
                metric: config.evaluation.metric,
                metricValue: metricValue,
                measurement: measurement,
                environment: environment,
                coefficientOfVariation: cv,
                outlierCount: outliers
            )

            // Append current record
            do {
                try await Tests.History.Storage.append(record, root: root)
            } catch {
                _diagLog(testName, "HISTORY_APPEND_ERROR: \(error)")
            }

            // Load full history (including the record we just appended)
            let records: [Tests.History.Record]
            do {
                records = try await Tests.History.Storage.load(
                    root: root,
                    testID: entry.id,
                    fingerprint: environment.fingerprint
                )
            } catch {
                _diagLog(testName, "HISTORY_LOAD_ERROR: \(error)")
                records = []
            }
            historyAnalysis = Tests.History.Analysis.analyze(records)
        }

        _diagLog(testName, "HISTORY_DONE")

        let diagnostic = Tests.Diagnostic(
            testName: entry.id.name,
            suiteName: entry.id.suite,
            qualifiedName: entry.id.fullyQualifiedName,
            metric: config.evaluation.metric,
            measurement: measurement,
            environment: environment,
            coefficientOfVariation: cv,
            medianAbsoluteDeviation: mad,
            outlierCount: outliers,
            trend: trend,
            threshold: config.evaluation.threshold,
            exceedanceFactor: factor,
            allocations: allocationStats,
            baseline: storedBaseline,
            comparison: comparison,
            historyAnalysis: historyAnalysis
        )

        // Register with global collector for event emission and summary table.
        // The runner drains the collector after all tests complete and emits
        // events + console output from a single coordination point.
        Tests.Diagnostic.Collector.shared.append(diagnostic)
        _diagLog(testName, "SCOPE_DONE")

        // Throw if threshold exceeded
        if exceeded {
            throw .benchmarkFailed(.thresholdExceeded(
                test: entry.id.name,
                metric: config.evaluation.metric,
                expected: config.evaluation.threshold!,
                actual: metricValue
            ))
        }

        // Throw if baseline regression exceeded
        if let comparison, let tolerance = config.evaluation.baselineTolerance,
            comparison.change > tolerance
        {
            throw .benchmarkFailed(.regressionDetected(
                test: entry.id.name,
                metric: config.evaluation.metric,
                baseline: comparison.baselineValue,
                current: comparison.currentValue,
                regression: comparison.change,
                tolerance: tolerance
            ))
        }
    }
}

// MARK: - Timestamp

import Kernel

/// Returns current Unix epoch seconds via the platform's realtime clock.
private func _epochSeconds() -> Double {
    Kernel.Time.realtimeEpochSeconds()
}

/// Append one diagnostic line to `/tmp/io-bench-hang-diag.log`.
/// Uses File_System (synchronous). Each write is < 200 bytes — trivial.
private func _diagLog(_ test: Swift.String, _ phase: Swift.String) {
    let line = "\(_epochSeconds()) | \(test) | \(phase)\n"
    try? File(File.Path(stringLiteral: "/tmp/io-bench-hang-diag.log")).write.append(line)
}

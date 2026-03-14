//
//  Test.Trait.Scope.Provider.timed.swift
//  swift-tests
//
//  Scope provider for timed benchmark execution.
//

import Clocks
import Memory
import File_System

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

        let measurement = Test.Benchmark.Measurement(durations: durations)

        // Capture environment (needed for both diagnostics and baseline keying)
        let environment = Test.Environment.capture()

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
            storedBaseline = Tests.Baseline.Storage.load(at: baselinePath)

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
                    try? Tests.Baseline.Storage.save(measurement, to: baselinePath)
                }
            } else {
                // No baseline exists
                switch recording {
                case .normal, .all:
                    // Save current measurement as the new baseline
                    try? Tests.Baseline.Storage.save(measurement, to: baselinePath)
                case .never:
                    throw .baselineMissing(
                        test: entry.id.name,
                        path: Swift.String(baselinePath)
                    )
                }
            }
        }

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
            try? Tests.History.Storage.append(record, root: root)

            // Load full history (including the record we just appended)
            let records = Tests.History.Storage.load(
                root: root,
                testID: entry.id,
                fingerprint: environment.fingerprint
            )
            historyAnalysis = Tests.History.Analysis.analyze(records)
        }

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

        // Register with global collector for summary table
        Tests.Diagnostic.Collector.shared.append(diagnostic)

        // Print results if configured
        if config.evaluation.printResults {
            print(diagnostic.formatted())
            print(diagnostic.jsonBlock())
        }

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

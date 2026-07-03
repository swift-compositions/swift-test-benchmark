// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-tests open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-tests project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Clocks
public import Test_Primitives
public import Time_Primitives

extension Test.Benchmark {
    /// Measures the execution time of a block of code with multiple iterations.
    ///
    /// Use this when you need stable state across iterations (e.g., the test struct's
    /// init runs expensive setup). The `.timed()` trait creates a new test instance
    /// per iteration, while `measure` runs all iterations within a single invocation.
    ///
    /// ```swift
    /// @Test("move files benchmark")
    /// func moveFiles() async throws {
    ///     // Setup (done once)
    ///     let fixture = try await FileSystemFixture.make()
    ///     createFiles(fixture)
    ///
    ///     // Measured iterations (same state)
    ///     try Test.Benchmark.measure(iterations: 3, warmup: 1, name: "move x 1000") {
    ///         for i in 0..<1000 {
    ///             try moveFile(i)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - iterations: Number of timed iterations to run.
    ///   - warmup: Number of warmup iterations (not timed).
    ///   - name: Optional name for the measurement output.
    ///   - threshold: Optional performance threshold to enforce.
    ///   - metric: Which metric to check against threshold.
    ///   - body: The code block to measure.
    /// - Throws: Rethrows any error from the body, or fails if threshold exceeded.
    @discardableResult
    public static func measure<E: Swift.Error>(
        iterations: Int = 10,
        warmup: Int = 0,
        name: Swift.String? = nil,
        threshold: Duration? = nil,
        metric: Metric = .median,
        _ body: () throws(E) -> Void
    ) throws(E) -> Measurement {
        // Warmup
        for _ in 0..<warmup {
            try body()
        }

        // Measure
        var durations: [Duration] = []
        durations.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = Clock_Primitives.Clock.Continuous.now
            try body()
            durations.append(Clock_Primitives.Clock.Continuous.now - start)
        }

        let measurement = Measurement(durations: durations)

        // Print results
        let displayName = name ?? "Benchmark"
        printPerformance(displayName, measurement)

        // Check threshold
        if let threshold {
            let actualMetric = metric.extract(from: measurement)
            if actualMetric > threshold {
                print(
                    """
                    ⚠️ Performance threshold exceeded in '\(displayName)':
                    Expected \(metric): < \(threshold.formatted())
                    Actual \(metric): \(actualMetric.formatted())
                    """
                )
            }
        }

        return measurement
    }

    /// Async version of measure for async test bodies.
    @discardableResult
    public static func measure<E: Swift.Error>(
        iterations: Int = 10,
        warmup: Int = 0,
        name: Swift.String? = nil,
        threshold: Duration? = nil,
        metric: Metric = .median,
        _ body: () async throws(E) -> Void
    ) async throws(E) -> Measurement {
        // Warmup
        for _ in 0..<warmup {
            try await body()
        }

        // Measure
        var durations: [Duration] = []
        durations.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = Clock_Primitives.Clock.Continuous.now
            try await body()
            durations.append(Clock_Primitives.Clock.Continuous.now - start)
        }

        let measurement = Measurement(durations: durations)

        // Print results
        let displayName = name ?? "Benchmark"
        printPerformance(displayName, measurement)

        // Check threshold
        if let threshold {
            let actualMetric = metric.extract(from: measurement)
            if actualMetric > threshold {
                print(
                    """
                    ⚠️ Performance threshold exceeded in '\(displayName)':
                    Expected \(metric): < \(threshold.formatted())
                    Actual \(metric): \(actualMetric.formatted())
                    """
                )
            }
        }

        return measurement
    }

    /// Prints a performance measurement summary.
    @usableFromInline
    static func printPerformance(_ name: Swift.String, _ measurement: Measurement) {
        print(
            """
            ⏱️ \(name)
               Iterations: \(measurement.durations.count)
               Min:        \(measurement.min.formatted())
               Median:     \(measurement.median.formatted())
               Mean:       \(measurement.mean.formatted())
               p95:        \(measurement.p95.formatted())
               p99:        \(measurement.p99.formatted())
               Max:        \(measurement.max.formatted())
               StdDev:     \(measurement.standardDeviation.formatted())
            """
        )
    }
}

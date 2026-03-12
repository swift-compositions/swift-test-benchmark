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

public import Time_Primitives

extension Tests {
    /// Assert that an operation completes within a duration threshold
    ///
    /// Example:
    /// ```swift
    /// try Tests.expect(lessThan: .milliseconds(100)) {
    ///     numbers.sum()
    /// }
    /// ```
    @discardableResult
    public static func expect<T>(
        lessThan threshold: Duration,
        warmup: Int = 0,
        iterations: Int = 10,
        metric: Test.Benchmark.Metric = .median,
        operation: () -> T
    ) throws(Tests.Error) -> (result: T, measurement: Test.Benchmark.Measurement) {
        let (result, measurement) = measure(
            warmup: warmup,
            iterations: iterations,
            operation: operation
        )

        let actualDuration = metric.extract(from: measurement)

        guard actualDuration <= threshold else {
            throw Tests.Error.benchmarkFailed(.thresholdExceeded(
                test: "",
                metric: metric,
                expected: threshold,
                actual: actualDuration
            ))
        }

        return (result, measurement)
    }

    /// Assert that an async operation completes within a duration threshold.
    ///
    /// The operation must be non-throwing (symmetric with the sync overload).
    /// If benchmarking a throwing operation, handle errors inside the closure.
    @discardableResult
    public static func expect<T>(
        lessThan threshold: Duration,
        warmup: Int = 0,
        iterations: Int = 10,
        metric: Test.Benchmark.Metric = .median,
        operation: () async -> T
    ) async throws(Tests.Error) -> (result: T, measurement: Test.Benchmark.Measurement) {
        let (result, measurement) = await measure(
            warmup: warmup,
            iterations: iterations,
            operation: operation
        )

        let actualDuration = metric.extract(from: measurement)

        guard actualDuration <= threshold else {
            throw Tests.Error.benchmarkFailed(.thresholdExceeded(
                test: "",
                metric: metric,
                expected: threshold,
                actual: actualDuration
            ))
        }

        return (result, measurement)
    }
}

extension Tests {
    /// Performance regression detector
    ///
    /// Compares current performance against a baseline with tolerance.
    ///
    /// Example:
    /// ```swift
    /// let baseline = Test.Benchmark.Measurement(durations: [.milliseconds(10)])
    /// let (result, measurement) = Tests.measure { operation() }
    ///
    /// Tests.expectNoRegression(
    ///     current: measurement,
    ///     baseline: baseline,
    ///     tolerance: 0.10  // 10% regression allowed
    /// )
    /// ```
    // WORKAROUND: Compound method name expectNoRegression [API-NAME-002]
    // WHY: "no regression" is an indivisible semantic concept — splitting across
    //   Swift parameter labels produces awkward signatures that obscure intent.
    // WHEN TO REMOVE: When a Property-based nested accessor (e.g. expect.noRegression)
    //   is available for the Tests namespace.
    // TRACKING: naming-implementation-audit-swift-tests-swift-testing.md N16
    public static func expectNoRegression(
        current: Test.Benchmark.Measurement,
        baseline: Test.Benchmark.Measurement,
        tolerance: Double = 0.10,
        metric: Test.Benchmark.Metric = .median
    ) throws(Tests.Error) {
        let comparison = Tests.Comparison(
            name: "",
            current: current,
            baseline: baseline,
            metric: metric
        )

        guard comparison.change <= tolerance else {
            throw Tests.Error.benchmarkFailed(.regressionDetected(
                test: "",
                metric: metric,
                baseline: comparison.baselineValue,
                current: comparison.currentValue,
                regression: comparison.change,
                tolerance: tolerance
            ))
        }
    }
}

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
    /// try Tests.expectPerformance(lessThan: .milliseconds(100)) {
    ///     numbers.sum()
    /// }
    /// ```
    @discardableResult
    public static func expectPerformance<T>(
        lessThan threshold: Duration,
        warmup: Int = 0,
        iterations: Int = 10,
        metric: Tests.Metric = .median,
        operation: () -> T
    ) throws(Tests.Error) -> (result: T, measurement: Tests.Measurement) {
        let (result, measurement) = measure(
            warmup: warmup,
            iterations: iterations,
            operation: operation
        )

        let actualDuration = metric.extract(from: measurement)

        guard actualDuration <= threshold else {
            throw Tests.Error.performanceExpectationFailed(
                metric: metric,
                threshold: threshold,
                actual: actualDuration
            )
        }

        return (result, measurement)
    }

    /// Assert that an async operation completes within a duration threshold.
    ///
    /// The operation must be non-throwing (symmetric with the sync overload).
    /// If benchmarking a throwing operation, handle errors inside the closure.
    @discardableResult
    public static func expectPerformance<T>(
        lessThan threshold: Duration,
        warmup: Int = 0,
        iterations: Int = 10,
        metric: Tests.Metric = .median,
        operation: () async -> T
    ) async throws(Tests.Error) -> (result: T, measurement: Tests.Measurement) {
        let (result, measurement) = await measure(
            warmup: warmup,
            iterations: iterations,
            operation: operation
        )

        let actualDuration = metric.extract(from: measurement)

        guard actualDuration <= threshold else {
            throw Tests.Error.performanceExpectationFailed(
                metric: metric,
                threshold: threshold,
                actual: actualDuration
            )
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
    /// let baseline = Tests.Measurement(durations: [.milliseconds(10)])
    /// let (result, measurement) = Tests.measure { operation() }
    ///
    /// Tests.expectNoRegression(
    ///     current: measurement,
    ///     baseline: baseline,
    ///     tolerance: 0.10  // 10% regression allowed
    /// )
    /// ```
    public static func expectNoRegression(
        current: Tests.Measurement,
        baseline: Tests.Measurement,
        tolerance: Double = 0.10,
        metric: Tests.Metric = .median
    ) throws(Tests.Error) {
        let comparison = Tests.Comparison(
            name: "",
            current: current,
            baseline: baseline,
            metric: metric
        )

        guard comparison.change <= tolerance else {
            throw Tests.Error.regressionDetected(
                metric: metric,
                baseline: comparison.baselineValue,
                current: comparison.currentValue,
                regression: comparison.change,
                tolerance: tolerance
            )
        }
    }
}

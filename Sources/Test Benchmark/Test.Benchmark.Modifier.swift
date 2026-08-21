// This source file is part of the swift-test-benchmark open source project
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and project authors
// Licensed under Apache License v2.0

public import Benchmark
public import Test

extension Test.Benchmark {
    public struct Modifier<WorkloadState: Sendable, WorkloadFailure: Swift.Error, ProbeState: Sendable, Observation: Sendable, ProbeFailure: Swift.Error>: Test.Modifier {
        public let plan: Benchmark.Plan
        public let workload: Benchmark.Workload<WorkloadState, WorkloadFailure>
        public let probe: Benchmark.Probe<ProbeState, Observation, ProbeFailure>
        public let association: Association
        public let recorder: Test.Recorder
        public let evaluation: @Sendable (Benchmark.Receipt<Observation>) -> Benchmark.Comparison
        public let inheritance: Test.Scope.Inheritance

        public init(
            plan: Benchmark.Plan,
            workload: Benchmark.Workload<WorkloadState, WorkloadFailure>,
            probe: Benchmark.Probe<ProbeState, Observation, ProbeFailure>,
            association: Association,
            recorder: Test.Recorder,
            inheritance: Test.Scope.Inheritance = .recursive,
            evaluation: @escaping @Sendable (Benchmark.Receipt<Observation>) -> Benchmark.Comparison = { _ in .unchanged }
        ) {
            self.plan = plan
            self.workload = workload
            self.probe = probe
            self.association = association
            self.recorder = recorder
            self.inheritance = inheritance
            self.evaluation = evaluation
        }
    }
}

extension Test.Benchmark.Modifier {
    public func apply<R: ~Copyable, E: Swift.Error>(
        in context: Test.Context,
        isolation: isolated (any Actor)?,
        operation: @isolated(any) () async throws(E) -> sending R
    ) async throws(E) -> sending R {
        try await operation()
    }

    public func scope<E: Swift.Error>(
        in context: Test.Context,
        isolation: isolated (any Actor)?,
        operation: @isolated(any) () async throws(E) -> sending Void
    ) async throws(E) {
        try await context.with(isolation: isolation, operation: operation)
        guard let receipt = Test.Benchmark.measure(
            plan: plan,
            workload: workload,
            probe: probe,
            association: association,
            recorder: recorder
        ) else { return }
        Test.Benchmark.assert(evaluation(receipt), association: association, recorder: recorder)
    }
}

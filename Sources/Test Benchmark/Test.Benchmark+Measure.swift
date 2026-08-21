// This source file is part of the swift-test-benchmark open source project
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and project authors
// Licensed under Apache License v2.0

public import Benchmark
public import Test

extension Test.Benchmark {
    public static func measure<WorkloadState: Sendable, WorkloadFailure: Swift.Error, ProbeState: Sendable, Observation: Sendable, ProbeFailure: Swift.Error>(
        plan: Benchmark.Plan,
        workload: Benchmark.Workload<WorkloadState, WorkloadFailure>,
        probe: Benchmark.Probe<ProbeState, Observation, ProbeFailure>,
        association: Association,
        recorder: Test.Recorder
    ) -> Benchmark.Receipt<Observation>? {
        do throws(Benchmark.Execution.Failure<WorkloadFailure, ProbeFailure>) {
            return try Benchmark.run(plan: plan, workload: workload, probe: probe)
        } catch {
            recorder(.init(kind: .error, message: .init("Benchmark failed: \(association.name): \(error)"), source: association.source))
            return nil
        }
    }
}

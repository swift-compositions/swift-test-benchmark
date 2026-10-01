// This source file is part of the swift-test-benchmark open source project
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and project authors
// Licensed under Apache License v2.0

public import Benchmark
public import Test

extension Test.Benchmark {
    public static func measure<WorkloadState: Sendable, WorkloadFailure: Swift.Error, ProbeState: Sendable, Observation: Sendable, ProbeFailure: Swift.Error>(
        plan: Benchmark::Benchmark.Plan,
        workload: Benchmark::Benchmark.Workload<WorkloadState, WorkloadFailure>,
        probe: Benchmark::Benchmark.Probe<ProbeState, Observation, ProbeFailure>,
        association: Association,
        recorder: @Sendable (Test.Issue) -> Void
    ) -> Benchmark::Benchmark.Receipt<Observation>? {
        do throws(Benchmark::Benchmark.Execution.Failure<WorkloadFailure, ProbeFailure>) {
            return try Benchmark::Benchmark.run(plan: plan, workload: workload, probe: probe)
        } catch {
            recorder(
                Test.Issue(
                    kind: .errorCaught(
                        type: String(reflecting: type(of: error)),
                        description: Test.Text("Benchmark failed: \(association.name): \(error)")
                    ),
                    sourceLocation: association.source
                )
            )
            return nil
        }
    }
}

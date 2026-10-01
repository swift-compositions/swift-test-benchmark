// This source file is part of the swift-test-benchmark open source project
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and project authors
// Licensed under Apache License v2.0

public import Benchmark
public import Test

extension Test.Benchmark {
    public static func assert(
        _ comparison: Benchmark::Benchmark.Comparison,
        association: Association,
        recorder: @Sendable (Test.Issue) -> Void
    ) {
        switch comparison {
        case .improved, .unchanged: return
        case .regressed:
            recorder(
                Test.Issue(
                    kind: .unconditional(Test.Text("Benchmark regressed: \(association.name)")),
                    sourceLocation: association.source
                )
            )
        case .inconclusive:
            recorder(
                Test.Issue(
                    kind: .system(Test.Text("Benchmark is inconclusive: \(association.name)")),
                    sourceLocation: association.source,
                    isKnown: true
                )
            )
        }
    }
}

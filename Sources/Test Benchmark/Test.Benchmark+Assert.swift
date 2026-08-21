// This source file is part of the swift-test-benchmark open source project
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and project authors
// Licensed under Apache License v2.0

// swift-linter:disable:next target import edge
// REASON: The declared Benchmark product is module-aliased to disambiguate Test.Benchmark; the manifest scanner does not model moduleAliases.
public import Benchmark
// swift-linter:disable:next target import edge
// REASON: Test is a direct product dependency; the preceding module alias currently prevents the manifest scanner from recognizing later edges.
public import Test

extension Test.Benchmark {
    public static func assert(
        _ comparison: Benchmark.Comparison,
        association: Association,
        recorder: Test.Recorder
    ) {
        switch comparison {
        case .improved, .unchanged: return
        case .regressed:
            recorder(.init(kind: .assertion, message: .init("Benchmark regressed: \(association.name)"), source: association.source))
        case .inconclusive:
            recorder(.init(kind: .system, message: .init("Benchmark is inconclusive: \(association.name)"), source: association.source, isKnown: true))
        }
    }
}

//
//  Test.Trait.Key.Timed.swift
//  swift-tests
//
//  Witness key for timed benchmark traits.
//

extension Test.Trait {
    /// Witness key for timed benchmark configuration.
    public struct Timed: Sendable {}
}

extension Test.Trait.Timed: Witness.Key {
    public typealias Value = Test.Benchmark.Configuration?

    @inlinable
    public static var liveValue: Test.Benchmark.Configuration? { nil }
}

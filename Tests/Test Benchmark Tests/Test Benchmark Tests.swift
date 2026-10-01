import Benchmark
import Cardinal
import Source
import Synchronization
import Test
import Test_Benchmark
import Testing

enum Relation {}

extension Relation {
    @Suite struct Test {
        @Suite struct Unit {
            @Test func `measure maps execution failure to a neutral issue`() throws {
                enum Failure: Swift.Error { case expected }
                let issues = Mutex<[NeutralTest.Issue]>([])
                let association = NeutralTest.Benchmark.Association(
                    name: "failure",
                    source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
                )
                let receipt = NeutralTest.Benchmark.measure(
                    plan: try .init(warmup: 0, measurements: 1, batch: 1),
                    workload: BenchmarkModel.Workload<Void, Failure>(setup: { () }, operation: { _ throws(Failure) in throw .expected }, teardown: { _ in }),
                    probe: BenchmarkModel.Probe<Void, Int, Never>(start: { .success(()) }, stop: { .success(1) }),
                    association: association,
                    recorder: { value in issues.withLock { $0.append(value) } }
                )
                #expect(receipt == nil)
                let recorded = issues.withLock { $0 }
                #expect(recorded.count == 1)
                #expect(recorded.first?.sourceLocation == association.source)
                #expect(recorded.first.map { if case .errorCaught = $0.kind { true } else { false } } == true)
            }

            @Test func `improved and unchanged comparisons record no issue`() {
                let issues = Mutex<[NeutralTest.Issue]>([])
                let association = NeutralTest.Benchmark.Association(
                    name: "steady",
                    source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
                )
                NeutralTest.Benchmark.assert(.improved, association: association, recorder: { value in issues.withLock { $0.append(value) } })
                NeutralTest.Benchmark.assert(.unchanged, association: association, recorder: { value in issues.withLock { $0.append(value) } })
                #expect(issues.withLock { $0.isEmpty })
            }

            @Test func `a regressed comparison records one unconditional issue at the association source`() {
                let issues = Mutex<[NeutralTest.Issue]>([])
                let association = NeutralTest.Benchmark.Association(
                    name: "slower",
                    source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
                )
                NeutralTest.Benchmark.assert(.regressed, association: association, recorder: { value in issues.withLock { $0.append(value) } })
                let recorded = issues.withLock { $0 }
                #expect(recorded.count == 1)
                #expect(recorded.first?.sourceLocation == association.source)
                #expect(recorded.first?.isKnown == false)
                #expect(recorded.first.map { if case .unconditional = $0.kind { true } else { false } } == true)
            }
        }

        @Suite struct `Edge Case` {
            @Test func `inconclusive evaluation is retained as known system evidence`() {
                let issues = Mutex<[NeutralTest.Issue]>([])
                NeutralTest.Benchmark.assert(
                    .inconclusive,
                    association: .init(name: "sample", source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)),
                    recorder: { value in issues.withLock { $0.append(value) } }
                )
                #expect(issues.withLock { $0.first?.isKnown } == true)
                #expect(issues.withLock { $0.first.map { if case .system = $0.kind { true } else { false } } } == true)
            }

            @Test func `a throwing body propagates and runs no benchmark`() async throws {
                enum Failure: Swift.Error { case body }
                let issues = Mutex<[NeutralTest.Issue]>([])
                let modifier = NeutralTest.Benchmark.Modifier(
                    plan: try BenchmarkModel.Plan(warmup: 1, measurements: 2, batch: 3),
                    workload: BenchmarkModel.Workload<Int, Never>(setup: { 0 }, operation: { $0 += 1 }, teardown: { _ in }),
                    probe: BenchmarkModel.Probe<Void, Int, Never>(start: { .success(()) }, stop: { .success(1) }),
                    association: .init(name: "throws", source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)),
                    recorder: { value in issues.withLock { $0.append(value) } },
                    evaluation: { _ in .regressed }
                )
                await #expect(throws: Failure.self) {
                    try await modifier.scope(isolation: nil) { () async throws(Failure) in throw .body }
                }
                #expect(issues.withLock { $0.isEmpty })
            }
        }

        @Suite struct Integration {
            @Test func `modifier calls body once and repeats only the workload`() async throws {
                let body = Count()
                let issues = Mutex<[NeutralTest.Issue]>([])
                let modifier = NeutralTest.Benchmark.Modifier(
                    plan: try BenchmarkModel.Plan(warmup: 1, measurements: 2, batch: 3),
                    workload: BenchmarkModel.Workload<Int, Never>(setup: { 0 }, operation: { $0 += 1 }, teardown: { _ in }),
                    probe: BenchmarkModel.Probe<Void, Int, Never>(start: { .success(()) }, stop: { .success(1) }),
                    association: .init(name: "body", source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)),
                    recorder: { value in issues.withLock { $0.append(value) } },
                    evaluation: { $0.measurement.values.count == 2 ? .unchanged : .regressed }
                )
                await modifier.scope(isolation: nil) { await body.increment() }
                #expect(await body.value == 1)
                #expect(issues.withLock { $0.isEmpty })
            }

            @Test func `apply forwards the operation once without benchmarking`() async throws {
                let body = Count()
                let issues = Mutex<[NeutralTest.Issue]>([])
                let modifier = NeutralTest.Benchmark.Modifier(
                    plan: try BenchmarkModel.Plan(warmup: 1, measurements: 2, batch: 3),
                    workload: BenchmarkModel.Workload<Int, Never>(setup: { 0 }, operation: { $0 += 1 }, teardown: { _ in }),
                    probe: BenchmarkModel.Probe<Void, Int, Never>(start: { .success(()) }, stop: { .success(1) }),
                    association: .init(name: "apply", source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)),
                    recorder: { value in issues.withLock { $0.append(value) } },
                    evaluation: { _ in .regressed }
                )
                let result = await modifier.apply(isolation: nil) { await body.increment(); return 7 }
                #expect(result == 7)
                #expect(await body.value == 1)
                #expect(issues.withLock { $0.isEmpty })
            }
        }
    }
}

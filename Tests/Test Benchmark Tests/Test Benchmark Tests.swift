import Benchmark
import Cardinal_Primitives_Standard_Library_Integration
import Source_Primitives
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
                let recorder = NeutralTest.Recorder(issue: { value in issues.withLock { $0.append(value) } })
                let association = NeutralTest.Benchmark.Association(
                    name: "failure",
                    source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
                )
                let receipt = NeutralTest.Benchmark.measure(
                    plan: try .init(warmup: 0, measurements: 1, batch: 1),
                    workload: BenchmarkModel.Workload<Void, Failure>(setup: { () }, operation: { _ throws(Failure) in throw .expected }, teardown: { _ in }),
                    probe: BenchmarkModel.Probe<Void, Int, Never>(start: { .success(()) }, stop: { .success(1) }),
                    association: association,
                    recorder: recorder
                )
                #expect(receipt == nil)
                #expect(issues.withLock { $0.count } == 1)
            }
        }

        @Suite struct `Edge Case` {
            @Test func `inconclusive evaluation is retained as known system evidence`() {
                let issues = Mutex<[NeutralTest.Issue]>([])
                let recorder = NeutralTest.Recorder(issue: { value in issues.withLock { $0.append(value) } })
                NeutralTest.Benchmark.assert(
                    .inconclusive,
                    association: .init(name: "sample", source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)),
                    recorder: recorder
                )
                #expect(issues.withLock { $0.first?.isKnown } == true)
            }
        }

        @Suite struct Integration {
            @Test func `modifier calls body once and repeats only the workload`() async throws {
                let body = Count()
                let issues = Mutex<[NeutralTest.Issue]>([])
                let recorder = NeutralTest.Recorder(issue: { value in issues.withLock { $0.append(value) } })
                let modifier = NeutralTest.Benchmark.Modifier(
                    plan: try BenchmarkModel.Plan(warmup: 1, measurements: 2, batch: 3),
                    workload: BenchmarkModel.Workload<Int, Never>(setup: { 0 }, operation: { $0 += 1 }, teardown: { _ in }),
                    probe: BenchmarkModel.Probe<Void, Int, Never>(start: { .success(()) }, stop: { .success(1) }),
                    association: .init(name: "body", source: .init(fileID: #fileID, filePath: #filePath, line: #line, column: #column)),
                    recorder: recorder,
                    evaluation: { $0.measurement.values.count == 2 ? .unchanged : .regressed }
                )
                let context = NeutralTest.Context(recorder: recorder)
                await modifier.scope(in: context, isolation: nil) { await body.increment() }
                #expect(await body.value == 1)
                #expect(issues.withLock { $0.isEmpty })
            }
        }
    }
}

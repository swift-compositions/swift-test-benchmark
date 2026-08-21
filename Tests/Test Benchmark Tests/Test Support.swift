import Benchmark
import Test
import Test_Benchmark

typealias NeutralTest = Test
typealias BenchmarkModel = Benchmark

actor Count {
    private(set) var value = 0
}

extension Count {
    func increment() { value += 1 }
}

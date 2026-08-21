# Test Benchmark

[![CI](https://github.com/swift-foundations/swift-test-benchmark/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-foundations/swift-test-benchmark/actions/workflows/ci.yml)

The Test × Benchmark relation: neutral test issues and scoped modifiers for metric-independent benchmark plans, workloads, probes, receipts, and evaluation.

```swift
import Test_Benchmark

let receipt = Test.Benchmark.measure(
    plan: plan,
    workload: workload,
    probe: probe,
    association: association,
    recorder: recorder
)
```

This package deliberately provides no clock or memory measurement. Consumers choose concrete Benchmark Clock and Benchmark Memory providers explicitly.

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).

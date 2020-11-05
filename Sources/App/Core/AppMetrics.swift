import Metrics
import Prometheus


enum AppMetrics {

    static var initialized = false

    static func bootstrap() {
        // prevent tests from boostrapping multiple times
        guard !initialized else { return }
        defer { initialized = true }
        let client = PrometheusClient()
        MetricsSystem.bootstrap(client)
    }

    // metrics

    enum Labels {
        struct Build: MetricLabels {
            var platform: String = ""
            var swiftVersion: String = ""

            init() {}

            init(_ platform: App.Build.Platform, _ swiftVersion: SwiftVersion) {
                self.platform = platform.rawValue
                self.swiftVersion = "\(swiftVersion)"
            }
        }
    }

    static var buildCreateTotal: PromCounter<Int, Labels.Build>? {
        counter("spi_build_create_total", Labels.Build.self)
    }

    static var buildTriggerTotal: PromCounter<Int, Labels.Build>? {
        counter("spi_build_trigger_total", Labels.Build.self)
    }
}


// MARK: - helpers

extension AppMetrics {

    static func counter<U: MetricLabels>(_ name: String, _ labels: U.Type) -> PromCounter<Int, U>? {
        try? MetricsSystem.prometheus()
            .createCounter(forType: Int.self, named: name, withLabelType: labels)
    }

}


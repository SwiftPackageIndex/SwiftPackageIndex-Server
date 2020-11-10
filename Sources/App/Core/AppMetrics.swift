import Metrics
import Prometheus
import Vapor


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

    static var analyzeCandidatesCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_analyze_candidates_count", EmptyLabels.self)
    }

    static var analyzeUpdateRepositorySuccessTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_analyze_update_repository_success_total", EmptyLabels.self)
    }

    static var analyzeUpdateRepositoryFailureTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_analyze_update_repository_failure_total", EmptyLabels.self)
    }

    static var analyzeVersionsAddedTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_analyze_versions_added_total", EmptyLabels.self)
    }

    static var analyzeVersionsDeletedTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_analyze_versions_deleted_total", EmptyLabels.self)
    }

    static var buildCandidatesCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_build_candidates_count", EmptyLabels.self)
    }

    static var buildPendingJobsCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_build_pending_jobs_count", EmptyLabels.self)
    }

    static var buildRunningJobsCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_build_running_jobs_count", EmptyLabels.self)
    }

    static var buildReportTotal: PromCounter<Int, Labels.Build>? {
        counter("spi_build_report_total", Labels.Build.self)
    }

    static var buildTriggerTotal: PromCounter<Int, Labels.Build>? {
        counter("spi_build_trigger_total", Labels.Build.self)
    }

    static var buildTrimTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_build_trim_total", EmptyLabels.self)
    }

    static var ingestCandidatesCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_ingest_candidates_count", EmptyLabels.self)
    }

    static var ingestMetadataSuccessTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_ingest_metadata_success_total", EmptyLabels.self)
    }

    static var ingestMetadataFailureTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_ingest_metadata_failure_total", EmptyLabels.self)
    }
}


// MARK: - helpers

extension AppMetrics {

    static func counter<U: MetricLabels>(_ name: String, _ labels: U.Type) -> PromCounter<Int, U>? {
        try? MetricsSystem.prometheus()
            .createCounter(forType: Int.self, named: name, withLabelType: labels)
    }

    static func gauge<U: MetricLabels>(_ name: String, _ labels: U.Type) -> PromGauge<Int, U>? {
        try? MetricsSystem.prometheus()
            .createGauge(forType: Int.self, named: name, withLabelType: labels)
    }

}


extension AppMetrics {

    /// Push collected metrics to push gateway. This is the delivery mechansim for processing commands, which do not expose
    /// a `/metrics` endpoint that could be scraped. Instead, they push to a gateway that is configured as a Prometheus
    /// scrape target.
    /// - Parameter client: client for POST request
    /// - Returns: future
    static func push(client: Client, jobName: String) -> EventLoopFuture<Void> {
        guard let pushGatewayUrl = Current.metricsPushGatewayUrl() else {
            return client.eventLoop.future(error: AppError.envVariableNotSet("METRICS_PUSHGATEWAY_URL"))
        }
        let url = URI(string: "\(pushGatewayUrl)/metrics/job/\(jobName)")

        let promise = client.eventLoop.makePromise(of: String.self)
        do {
            try MetricsSystem.prometheus().collect(into: promise)
        } catch {
            return client.eventLoop.future(error: error)
        }

        let req = promise.futureResult
            .flatMap { metrics in
                client.post(url) { req in
                    // append "\n" to avoid
                    //   text format parsing error in line 4: unexpected end of input stream
                    try req.content.encode(metrics + "\n")
                }
            }
            .transform(to: ())

        return req
    }

}

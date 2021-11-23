// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
        MetricsSystem.bootstrap(PrometheusMetricsFactory(client: client))
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

        struct Version: MetricLabels {
            var kind: String = ""

            init() {}
            
            init(_ kind: String) {
                self.kind = kind
            }

            init(_ reference: Reference?) {
                switch reference {
                    case .branch:
                        kind = "branch"
                    case .tag:
                        kind = "tag"
                    case .none:
                        kind = ""
                }
            }
        }
    }

    static var analyzeCandidatesCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_analyze_candidates_count", EmptyLabels.self)
    }

    static var analyzeTrimCheckoutsCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_analyze_trim_checkouts_count", EmptyLabels.self)
    }

    static var analyzeUpdateRepositorySuccessCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_analyze_update_repository_success_count", EmptyLabels.self)
    }

    static var analyzeUpdateRepositoryFailureCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_analyze_update_repository_failure_count", EmptyLabels.self)
    }

    static var analyzeVersionsAddedCount: PromGauge<Int, Labels.Version>? {
        gauge("spi_analyze_versions_added_count", Labels.Version.self)
    }

    static var analyzeVersionsDeletedCount: PromGauge<Int, Labels.Version>? {
        gauge("spi_analyze_versions_deleted_count", Labels.Version.self)
    }

    static var apiBuildReportTotal: PromCounter<Int, Labels.Build>? {
        counter("spi_api_build_report_total", Labels.Build.self)
    }

    static var apiPackageCollectionGetTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_api_package_collection_get_total", EmptyLabels.self)
    }

    static var apiSearchGetTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_api_search_get_total", EmptyLabels.self)
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

    static var buildThrottleCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_build_throttle_count", EmptyLabels.self)
    }

    static var buildTriggerCount: PromGauge<Int, Labels.Build>? {
        gauge("spi_build_trigger_count", Labels.Build.self)
    }

    static var buildTrimCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_build_trim_count", EmptyLabels.self)
    }

    static var githubRateLimitRemainingCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_github_rate_limit_remaining_count", EmptyLabels.self)
    }

    static var ingestCandidatesCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_ingest_candidates_count", EmptyLabels.self)
    }

    static var ingestDurationSeconds: PromGauge<Double, EmptyLabels>? {
        gauge("ingest_duration_seconds", EmptyLabels.self)
    }

    static var ingestMetadataSuccessCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_ingest_metadata_success_count", EmptyLabels.self)
    }

    static var ingestMetadataFailureCount: PromGauge<Int, EmptyLabels>? {
        gauge("spi_ingest_metadata_failure_count", EmptyLabels.self)
    }

    static var packageCollectionGetTotal: PromCounter<Int, EmptyLabels>? {
        counter("spi_package_collection_get_total", EmptyLabels.self)
    }

}


// MARK: - helpers

extension AppMetrics {

    static func counter<V: Numeric, L: MetricLabels>(_ name: String, _ labels: L.Type) -> PromCounter<V, L>? {
        try? MetricsSystem.prometheus()
            .createCounter(forType: V.self, named: name, withLabelType: labels)
    }

    static func gauge<V: DoubleRepresentable, L: MetricLabels>(_ name: String, _ labels: L.Type) -> PromGauge<V, L>? {
        try? MetricsSystem.prometheus()
            .createGauge(forType: V.self, named: name, withLabelType: labels)
    }

}


extension AppMetrics {

    /// Push collected metrics to push gateway. This is the delivery mechansim for processing commands, which do not expose
    /// a `/metrics` endpoint that could be scraped. Instead, they push to a gateway that is configured as a Prometheus
    /// scrape target.
    /// - Parameter client: client for POST request
    /// - Returns: future
    static func push(client: Client, logger: Logger, jobName: String) -> EventLoopFuture<Void> {
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
            .flatMapError { error in
                logger.warning("AppMetrics.push failed with error: \(error)")
                // absorb error - we don't want metrics issues to cause upstream failures
                return client.eventLoop.future()
            }
    }

}


extension PromGauge {
    @inlinable
    public func time(_ labels: Labels? = nil, since start: UInt64) {
        let delta = Double(DispatchTime.now().uptimeNanoseconds - start)
        self.set(.init(delta / 1_000_000_000), labels)
    }
}

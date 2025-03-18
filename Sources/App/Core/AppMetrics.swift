// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Dependencies
import Metrics
import Prometheus
import Synchronization
import Vapor


enum AppMetrics {

    static let initialized = Mutex(false)

    static func bootstrap() {
        // prevent tests from boostrapping multiple times
        guard !initialized.withLock({ $0 }) else { return }
        initialized.withLock {
            let client = PrometheusClient()
            MetricsSystem.bootstrap(PrometheusMetricsFactory(client: client))
            $0 = true
        }
    }

    // metrics

    static var analyzeCandidatesCount: PromGauge<Int>? {
        gauge("spi_analyze_candidates_count")
    }

    static var analyzeDurationSeconds: PromGauge<Double>? {
        gauge("spi_analyze_duration_seconds")
    }

    static var analyzeTrimCheckoutsCount: PromGauge<Int>? {
        gauge("spi_analyze_trim_checkouts_count")
    }

    static var analyzeVersionsAddedCount: PromGauge<Int>? {
        gauge("spi_analyze_versions_added_count")
    }

    static var analyzeVersionsDeletedCount: PromGauge<Int>? {
        gauge("spi_analyze_versions_deleted_count")
    }

    static var apiBuildReportTotal: PromCounter<Int>? {
        counter("spi_api_build_report_total")
    }

    static var apiPackageCollectionGetTotal: PromCounter<Int>? {
        counter("spi_api_package_collection_get_total")
    }

    static var apiSearchGetTotal: PromCounter<Int>? {
        counter("spi_api_search_get_total")
    }

    static var apiSearchGetWithFilterTotal: PromCounter<Int>? {
        counter("spi_api_search_get_with_filter_total")
    }

    static var searchTermsCount: PromGauge<Int>? {
        gauge("spi_search_terms_count")
    }

    static var searchFiltersCount: PromGauge<Int>? {
        gauge("spi_search_filters_count")
    }

    static var buildCandidatesCount: PromGauge<Int>? {
        gauge("spi_build_candidates_count")
    }

    static var buildPendingJobsCount: PromGauge<Int>? {
        gauge("spi_build_pending_jobs_count")
    }

    static var buildRunningJobsCount: PromGauge<Int>? {
        gauge("spi_build_running_jobs_count")
    }

    static var buildThrottleCount: PromGauge<Int>? {
        gauge("spi_build_throttle_count")
    }

    static var buildTriggerCount: PromGauge<Int>? {
        gauge("spi_build_trigger_count")
    }

    static var buildTriggerDurationSeconds: PromGauge<Double>? {
        gauge("spi_build_trigger_duration_seconds")
    }

    static var buildTrimCount: PromGauge<Int>? {
        gauge("spi_build_trim_count")
    }

    static var githubRateLimitRemainingCount: PromGauge<Int>? {
        gauge("spi_github_rate_limit_remaining_count")
    }

    static var ingestCandidatesCount: PromGauge<Int>? {
        gauge("spi_ingest_candidates_count")
    }

    static var ingestDurationSeconds: PromGauge<Double>? {
        gauge("spi_ingest_duration_seconds")
    }

    static var ingestMetadataSuccessCount: PromGauge<Int>? {
        gauge("spi_ingest_metadata_success_count")
    }

    static var ingestMetadataFailureCount: PromGauge<Int>? {
        gauge("spi_ingest_metadata_failure_count")
    }

    static var packageCollectionGetTotal: PromCounter<Int>? {
        counter("spi_package_collection_get_total")
    }

    static var packageShowAvailableTotal: PromCounter<Int>? {
        counter("spi_package_show_available_total")
    }

    static var packageShowMissingTotal: PromCounter<Int>? {
        counter("spi_package_show_missing_total")
    }

    static var packageShowNonexistentTotal: PromCounter<Int>? {
        counter("spi_package_show_nonexistent_total")
    }

    static var reconcileDurationSeconds: PromGauge<Double>? {
        gauge("spi_reconcile_duration_seconds")
    }

}


// MARK: - helpers

extension AppMetrics {

    static func counter<V: Numeric>(_ name: String) -> PromCounter<V>? {
        try? MetricsSystem.prometheus()
            .createCounter(forType: V.self, named: name)
    }

    static func gauge<V: DoubleRepresentable>(_ name: String) -> PromGauge<V>? {
        try? MetricsSystem.prometheus()
            .createGauge(forType: V.self, named: name)
    }

}


extension AppMetrics {

    /// Push collected metrics to push gateway. This is the delivery mechansim for processing commands, which do not expose
    /// a `/metrics` endpoint that could be scraped. Instead, they push to a gateway that is configured as a Prometheus
    /// scrape target.
    /// - Parameter client: client for POST request
    static func push(client: Client, jobName: String) async throws {
        @Dependency(\.environment) var environment
        @Dependency(\.logger) var logger

        guard let pushGatewayUrl = environment.metricsPushGatewayUrl() else {
            throw AppError.envVariableNotSet("METRICS_PUSHGATEWAY_URL")
        }
        let url = URI(string: "\(pushGatewayUrl)/metrics/job/\(jobName)")

        do {
            let metrics: String = try await MetricsSystem.prometheus().collect()
            _ = try await client.post(url) { req in
                // append "\n" to avoid
                //   text format parsing error in line 4: unexpected end of input stream
                try req.content.encode(metrics + "\n")
            }
        } catch {
            logger.warning("AppMetrics.push failed with error: \(error)")
            // ignore error - we don't want metrics issues to cause upstream failures
        }
    }

}


extension PromGauge {
    @inlinable
    public func time(since start: UInt64, _ labels: DimensionLabels? = nil) {
        let delta = Double(DispatchTime.now().uptimeNanoseconds - start)
        self.set(.init(delta / 1_000_000_000), labels)
    }
}


extension DimensionLabels {

    static func buildReportLabels(_ build: App.Build) -> Self {
        .init([
            ("platform", build.platform.rawValue),
            ("swiftVersion", "\(build.swiftVersion)"),
        ])
    }

    static func buildTriggerLabels(_ pair: BuildPair) -> Self {
        .init([
            ("platform", pair.platform.rawValue),
            ("swiftVersion", "\(pair.swiftVersion)"),
        ])
    }

    static func versionLabels(reference: Reference?) -> Self {
        switch reference {
            case .none:
                return .init([])
            case .some(.branch):
                return .init([("kind", "branch")])
            case .some(.tag):
                return .init([("kind", "tag")])
        }
    }

    static func searchFilterLabels(_ key: SearchFilter.Key) -> Self {
        .init([("key", key.rawValue)])
    }

    static func searchFilterLabels(_ key: SearchFilter.Key, _ expression: SearchFilter.Expression) -> Self {
        .init([("key", key.rawValue), ("value", expression.value)])
    }

}

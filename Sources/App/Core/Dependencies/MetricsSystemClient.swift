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
import Synchronization
@preconcurrency import Prometheus


struct MetricsSystemClient {
    var prometheus: @Sendable () throws -> PrometheusClient
}


extension MetricsSystemClient {
    private static let initialized = Mutex(false)

    func bootstrap() {
        guard !Self.initialized.withLock({ $0 }) else { return }
        Self.initialized.withLock {
            let client = PrometheusClient()
            MetricsSystem.bootstrap(PrometheusMetricsFactory(client: client))
            $0 = true
        }
    }
}


extension MetricsSystemClient: DependencyKey {
    static var liveValue: Self {
        .init(prometheus: { try MetricsSystem.prometheus() })
    }
}


extension MetricsSystemClient: TestDependencyKey {
    static var testValue: Self {
        .init(prometheus: { unimplemented("testValue"); return .init() })
    }
}


extension DependencyValues {
    var metricsSystem: MetricsSystemClient {
        get { self[MetricsSystemClient.self] }
        set { self[MetricsSystemClient.self] = newValue }
    }
}


#if DEBUG
extension MetricsSystemClient {
    static var mock: Self {
        let prometheus = PrometheusClient()
        return .init(prometheus: { prometheus })
    }
}
#endif

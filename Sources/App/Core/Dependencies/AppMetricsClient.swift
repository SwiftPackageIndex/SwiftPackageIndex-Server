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


enum AppMetricsClient {
    private static let initialized = Mutex(false)

    static func bootstrap() {
        guard !initialized.withLock({ $0 }) else { return }
        initialized.withLock {
            let client = PrometheusClient()
            MetricsSystem.bootstrap(PrometheusMetricsFactory(client: client))
            $0 = true
        }
    }
}


extension AppMetricsClient: DependencyKey {
    static var liveValue: PrometheusClient? {
        try? MetricsSystem.prometheus()
    }
}


extension AppMetricsClient: TestDependencyKey {
    static var testValue: PrometheusClient? {
        unimplemented("testValue"); return nil
    }
}


extension DependencyValues {
    public var prometheus: PrometheusClient? {
        get { self[AppMetricsClient.self] }
        set { self[AppMetricsClient.self] = newValue }
    }
}

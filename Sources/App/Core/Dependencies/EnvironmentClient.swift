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
import DependenciesMacros
import Vapor


@DependencyClient
struct EnvironmentClient {
    // See https://swiftpackageindex.com/pointfreeco/swift-dependencies/main/documentation/dependenciesmacros/dependencyclient()#Restrictions
    // regarding the use of XCTFail here.
    var allowBuildTriggers: @Sendable () -> Bool = { XCTFail(#function); return true }
}


extension EnvironmentClient: DependencyKey {
    static var liveValue: EnvironmentClient {
        .init(
            allowBuildTriggers: {
                Environment.get("ALLOW_BUILD_TRIGGERS").flatMap(\.asBool) ?? Constants.defaultAllowBuildTriggering
            }
        )
    }
}


extension EnvironmentClient: TestDependencyKey {
    static var testValue: Self { Self() }
}


extension DependencyValues {
    var environment: EnvironmentClient {
        get { self[EnvironmentClient.self] }
        set { self[EnvironmentClient.self] = newValue }
    }
}
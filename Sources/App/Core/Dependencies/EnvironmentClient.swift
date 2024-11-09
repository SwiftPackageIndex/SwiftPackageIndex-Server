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
    var allowSocialPosts: @Sendable () -> Bool = { XCTFail(#function); return true }
    // We're not defaulting current to XCTFail, because its use is too pervasive and would require the vast
    // majority of tests to be wrapped with `withDependencies`.
    // We can do so at a later time once more tests are transitioned over for other dependencies. This is
    // the exact same default behaviour we have with the Current dependency injection: it defaults to
    // .development and does not raise an error when not injected.
    var current: @Sendable () -> Environment = { .development }
}


extension EnvironmentClient: DependencyKey {
    static var liveValue: EnvironmentClient {
        .init(
            allowBuildTriggers: {
                Environment.get("ALLOW_BUILD_TRIGGERS").flatMap(\.asBool) ?? Constants.defaultAllowBuildTriggering
            },
            allowSocialPosts: {
                Environment.get("ALLOW_SOCIAL_POSTS")
                    .flatMap(\.asBool)
                    ?? Constants.defaultAllowSocialPosts
            },
            current: { (try? Environment.detect()) ?? .development }
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

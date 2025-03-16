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
import IssueReporting
import Logging


private enum LoggerClient: DependencyKey {
    static var liveValue: Logger {
        reportIssue("The default logger is being used. Override this dependency in the entry point of your app.")
        return Logging.Logger(label: "default")
    }
}


extension LoggerClient: TestDependencyKey {
    static var testValue: Logger {
        unimplemented("testValue"); return .init(label: "test")
    }
}


extension DependencyValues {
    public var logger: Logger {
        get { self[LoggerClient.self] }
        set { self[LoggerClient.self] = newValue }
    }
}


#if DEBUG
extension Logger {
    static var noop: Self { .init(label: "noop") { _ in SwiftLogNoOpLogHandler() } }

    static func testLogger(_ handler: LogHandler) -> Self {
        .init(label: "test", factory: { _ in handler })
    }
}
#endif

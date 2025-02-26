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
import Logging
import Synchronization


@DependencyClient
struct LoggerClient {
    var log: @Sendable (_ level: Logging.Logger.Level, Logging.Logger.Message) -> Void
    var set: @Sendable (_ to: Logging.Logger) -> Void
}


extension LoggerClient {
    func critical(_ message: Logging.Logger.Message) { log(.critical, message) }
    func debug(_ message: Logging.Logger.Message) { log(.debug, message) }
    func error(_ message: Logging.Logger.Message) { log(.error, message) }
    func info(_ message: Logging.Logger.Message) { log(.info, message) }
    func warning(_ message: Logging.Logger.Message) { log(.warning, message) }
    func trace(_ message: Logging.Logger.Message) { log(.trace, message) }
    func report(error: Error, file: String = #fileID, function: String = #function, line: UInt = #line) {
        logger.report(error: error, file: file, function: function, line: line)
    }
    var logger: Logging.Logger { Self._logger.withLock { $0 } }
}


#if DEBUG
extension LoggerClient {
    func set(to handler: LogHandler?) {
        if let handler {
            let logger = Logger(label: "test", factory: { _ in handler })
            set(to: logger)
        }
    }
}
#endif


extension LoggerClient: DependencyKey {
    static var liveValue: Self {
        .init(
            log: { level, message in
                _logger.withLock { $0.log(level: level, message) }
            },
            set: { logger in
                _logger.withLock { $0 = logger }
            }
        )
    }

    private static let _logger = Mutex(Logging.Logger(component: "default"))
}


extension LoggerClient: TestDependencyKey {
    static var testValue: Self { liveValue }
}


extension DependencyValues {
    var logger: LoggerClient {
        get { self[LoggerClient.self] }
        set { self[LoggerClient.self] = newValue }
    }
}

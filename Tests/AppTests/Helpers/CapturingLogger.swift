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

import Logging


struct CapturingLogger: LogHandler {
    struct LogEntry: Equatable {
        var level: Logger.Level
        var message: String
    }

    var logs = QueueIsolated<[LogEntry]>([])
    var logLevel: Logger.Level = .warning

    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        logs.withValue { logs in
            logs.append(.init(level: level, message: "\(message)"))
        }
    }

    subscript(metadataKey _: String) -> Logger.Metadata.Value? {
        get { return nil }
        set { }
    }

    var metadata: Logger.Metadata {
        get { return [:] }
        set { }
    }

    func reset() {
        logs.withValue { $0 = [] }
    }
}

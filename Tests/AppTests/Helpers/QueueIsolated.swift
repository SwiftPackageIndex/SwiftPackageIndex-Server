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

import Foundation


// Modeled after ActorIsolated with synchronisation via a queue instead of an actor, allowing
// sync access where async isn't possible.

@dynamicMemberLookup
public final class QueueIsolated<Value: Sendable>: @unchecked Sendable {
    private let _queue = DispatchQueue(label: "queue-isolated")

    private var _value: Value

    public init(_ value: Value) {
        self._value = value
    }

    public var value: Value {
        get {
            _queue.sync { self._value }
        }
    }

    public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
        _queue.sync {
            self._value[keyPath: keyPath]
        }
    }

    public func withValue<T>(
        _ operation: (inout Value) throws -> T
    ) rethrows -> T {
        try _queue.sync {
            var value = self._value
            defer { self._value = value }
            return try operation(&value)
        }
    }

    public func setValue(_ newValue: Value) {
        _queue.async {
            self._value = newValue
        }
    }
}


extension QueueIsolated where Value == Int {
    public func increment(by delta: Int = 1) {
        withValue { $0 += delta }
    }

    public func decrement(by delta: Int = 1) {
        withValue { $0 -= delta }
    }
}

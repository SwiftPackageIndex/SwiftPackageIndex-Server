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


public enum Retry {
    public enum Error: Swift.Error {
        case maxAttemptsExceeded
    }

    public enum BackoffStrategy {
        case constant(Duration)

        func delay(attempt: Int) async throws {
            switch self {
                case .constant(let duration):
                    try await Task.sleep(for: duration)
            }
        }
    }
}


@discardableResult
public func run<T>(
    maxAttempts: Int = 3,
    backoff: Retry.BackoffStrategy = .constant(.milliseconds(100)),
    operation: (_ attempt: Int) async throws -> T,
    errorLogger logError: ((Error) -> Void) = { print("\($0)") }
) async throws -> T {
    var attemptsLeft = maxAttempts
    while attemptsLeft > 0 {
        let attempt = maxAttempts - attemptsLeft + 1
        do {
            return try await operation(attempt)
        } catch {
            logError(error)
            if attemptsLeft != maxAttempts {
                try? await backoff.delay(attempt: attempt)
            }
            attemptsLeft -= 1
        }
    }
    throw Retry.Error.maxAttemptsExceeded
}


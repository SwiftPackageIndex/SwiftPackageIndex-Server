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


@discardableResult
func run<T>(_ operation: () async throws -> T,
            defer deferredOperation: () async throws -> Void) async throws -> T {
    do {
        let result = try await operation()
        try await deferredOperation()
        return result
    } catch {
        try await deferredOperation()
        throw error
    }
}


@discardableResult
func run<T, E1: Error, E2: Error>(_ operation: () async throws(E1) -> T,
                                  rethrowing transform: (E1) -> E2) async throws(E2) -> T {
    do {
        let result = try await operation()
        return result
    } catch {
        throw transform(error)
    }
}


@discardableResult
func run<T, E1: Error, E2: Error>(_ operation: () throws(E1) -> T,
                                  rethrowing transform: (E1) -> E2) throws(E2) -> T {
    do {
        let result = try operation()
        return result
    } catch {
        throw transform(error)
    }
}

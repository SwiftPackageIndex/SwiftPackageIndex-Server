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


extension Result where Failure == Error {
    var isSucess: Bool {
        switch self {
            case .success:
                return true
            case .failure:
                return false
        }
    }

    var isError: Bool { return !isSucess }
}


// Not really a part of the Result type but closely enough related to put here
// Perhaps put this in AsyncDefer.swift and rename the file?
@discardableResult
func run<T, E1: Error, E2: Error>(_ operation: () async throws(E1) -> T,
                                  throwing transform: (E1) -> E2) async throws(E2) -> T {
    do {
        let result = try await operation()
        return result
    } catch {
        throw transform(error)
    }
}

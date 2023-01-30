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


extension ThrowingTaskGroup {
    mutating func results() async -> [Result<ChildTaskResult, Error>] {
        var results = [Result<ChildTaskResult, Error>]()
        while !isEmpty {
            do {
                guard let res = try await next() else { break }
                results.append(.success(res))
            } catch {
                results.append(.failure(error))
            }
        }
        return results
    }
}

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

@preconcurrency import Cache
import Dependencies


typealias CurrentReferenceCache = ExpiringCache<String, String>

extension CurrentReferenceCache {
    static let live = CurrentReferenceCache(duration: .minutes(5))

    func get(owner: String, repository: String) -> String? {
        let key = "\(owner)/\(repository)".lowercased()
        return self[key]
    }

    func set(owner: String, repository: String, reference: String?) async {
        let key = "\(owner)/\(repository)".lowercased()
        self[key] = reference
        @Dependency(\.currentReferenceCache) var currentReferenceCache
        await currentReferenceCache.set(owner: owner, repository: repository, reference: reference)
    }
}

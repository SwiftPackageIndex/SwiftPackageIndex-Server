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

import Fluent


struct Page<M> {
    var results: [M]
    var hasMoreResults: Bool
}


extension QueryBuilder {
    /// Add `offset` and `limit` to the query corresponding to the give page. NB: the number of elements returned can be up to `pageSize + 1`. Therefore ensure to limit the results via `.prefix(pageSize)`.
    /// The point of this is to be able to tell if there are more results without having to run a count or any other subsequent query.
    /// - Parameters:
    ///   - page: requested page, first page is 1
    ///   - pageSize: number of elements per page
    /// - Returns: a `QueryBuilder`
    func page(_ page: Int, size pageSize: Int) -> EventLoopFuture<Page<Model>> {
        // page is one-based, clamp it to ensure we get a >=0 offset
        let page = page.clamped(to: 1...)
        let offset = (page - 1) * pageSize
        let limit = pageSize + 1  // fetch one more so we can determine `hasMoreResults`
        return self
            .offset(offset)
            .limit(limit)
            .all()
            .map { results in
                .init(results: Array(results.prefix(pageSize)),
                      hasMoreResults: results.count > pageSize)
            }
    }
}

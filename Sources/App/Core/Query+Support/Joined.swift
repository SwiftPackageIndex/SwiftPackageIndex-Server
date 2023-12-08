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

import FluentKit


struct Joined<M: Model, R: Model>: ModelInitializable {
    private(set) var model: M
    private(set) var relation: R?

    init(model: M) {
        self.model = model
        self.relation = try? model.joined(R.self)
    }
}


extension Joined {
    static func query(
        on database: Database,
        join joinFilter: ComplexJoinFilter,
        method: DatabaseQuery.Join.Method = .inner) -> JoinedQueryBuilder<Joined> {
            .init(queryBuilder: M.query(on: database)
                    .join(R.self, on: joinFilter, method: method))
    }
}

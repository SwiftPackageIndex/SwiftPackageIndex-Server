// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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


/// JoinedQueryBuilder is a wrapper around QueryBuilder to allow Joined to be used like a Model query without actually being a Model
struct JoinedQueryBuilder<J: Joiner> {
    var queryBuilder: QueryBuilder<J.M>

    @discardableResult
    func filter(_ field: DatabaseQuery.Field, _ method: DatabaseQuery.Filter.Method, _ value: DatabaseQuery.Value) -> Self {
        queryBuilder.filter(field, method, value)
        return self
    }

    @discardableResult func filter<Joined>(_ schema: Joined.Type, _ filter: ModelValueFilter<Joined>) -> Self where Joined : Schema {
        queryBuilder.filter(schema, filter)
        return self
    }

    func sort<Field>(_ field: KeyPath<J.M, Field>, _ direction: DatabaseQuery.Sort.Direction = .ascending) -> Self where J.M == Field.Model, Field : QueryableProperty {
        // TODO: check that this sorts correctly
        _ = queryBuilder.sort(field, direction)
        return self
    }

    func sort(_ field: DatabaseQuery.Field, _ direction: DatabaseQuery.Sort.Direction) -> Self {
        _ = queryBuilder.sort(field, direction)
        return self
    }

    func sort<Joined, Field>(_ joined: Joined.Type, _ field: KeyPath<Joined, Field>, _ direction: DatabaseQuery.Sort.Direction = .ascending, alias: String? = nil) -> Self where Joined : Schema, Joined == Field.Model, Field : QueryableProperty {
        _ = queryBuilder.sort(joined, field, direction, alias: alias)
        return self
    }

    func all() -> EventLoopFuture<[J]> {
        queryBuilder.all()
            .mapEach(J.init(model:))
    }

    func first() -> EventLoopFuture<J?> {
        queryBuilder.first()
            .optionalMap(J.init(model:))
    }

    func page(_ page: Int, size pageSize: Int) -> EventLoopFuture<Page<J>> {
        queryBuilder.page(page, size: pageSize)
            .map { page in
            .init(results: page.results.map(J.init(model:)),
                  hasMoreResults: page.hasMoreResults)
            }
    }

}

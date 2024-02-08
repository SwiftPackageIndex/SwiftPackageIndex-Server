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


/// JoinedQueryBuilder is a wrapper around QueryBuilder to allow Joined to be used like a Model query without actually being a Model
struct JoinedQueryBuilder<J: ModelInitializable> {
    var queryBuilder: QueryBuilder<J.M>

    @discardableResult func filter(_ filter: ModelValueFilter<J.M>) -> Self {
        queryBuilder.filter(filter)
        return self
    }

    // periphery:ignore
    @discardableResult
    func filter(_ field: DatabaseQuery.Field, _ method: DatabaseQuery.Filter.Method, _ value: DatabaseQuery.Value) -> Self {
        queryBuilder.filter(field, method, value)
        return self
    }

    @discardableResult func filter<Joined, Field>(_ joined: Joined.Type, _ field: KeyPath<Joined, Field>, _ method: DatabaseQuery.Filter.Method, _ value: Field.Value) -> Self where Joined : Schema, Joined == Field.Model, Field : QueryableProperty {
        queryBuilder.filter(joined, field, method, value)
        return self
    }

    @discardableResult func filter<Joined>(_ schema: Joined.Type, _ filter: ModelValueFilter<Joined>) -> Self where Joined : Schema {
        queryBuilder.filter(schema, filter)
        return self
    }

    @discardableResult
    func group(
        _ relation: DatabaseQuery.Filter.Relation = .and,
        _ closure: (QueryBuilder<J.M>) throws -> ()
    ) rethrows -> Self {
        let group = QueryBuilder<J.M>(database: queryBuilder.database)
        try closure(group)
        if !group.query.filters.isEmpty {
            queryBuilder.query.filters.append(.group(group.query.filters, relation))
        }
        return self
    }

    func sort(_ sort: DatabaseQuery.Sort) -> Self {
        // the queryBuilder method is not marked with `@discardableResult`
        // (perhaps an oversight), therefore we need to ignore the return
        // value
        _ = queryBuilder.sort(sort)
        return self
    }

    func sort<Field>(_ field: KeyPath<J.M, Field>, _ direction: DatabaseQuery.Sort.Direction = .ascending) -> Self where J.M == Field.Model, Field : QueryableProperty {
        // the queryBuilder method is not marked with `@discardableResult`
        // (perhaps an oversight), therefore we need to ignore the return
        // value
        _ = queryBuilder.sort(field, direction)
        return self
    }

    func sort(_ field: DatabaseQuery.Field, _ direction: DatabaseQuery.Sort.Direction) -> Self {
        // the queryBuilder method is not marked with `@discardableResult`
        // (perhaps an oversight), therefore we need to ignore the return
        // value
        _ = queryBuilder.sort(field, direction)
        return self
    }

    func sort<Joined, Field>(_ joined: Joined.Type, _ field: KeyPath<Joined, Field>, _ direction: DatabaseQuery.Sort.Direction = .ascending, alias: String? = nil) -> Self where Joined : Schema, Joined == Field.Model, Field : QueryableProperty {
        // the queryBuilder method is not marked with `@discardableResult`
        // (perhaps an oversight), therefore we need to ignore the return
        // value
        _ = queryBuilder.sort(joined, field, direction, alias: alias)
        return self
    }

    @discardableResult func join<Foreign>(_ foreign: Foreign.Type, on filter: ComplexJoinFilter, method: DatabaseQuery.Join.Method = .inner) -> Self where Foreign : Schema {
        queryBuilder.join(foreign, on: filter, method: method)
        return self
    }

    @discardableResult func with<Relation>(_ relationKey: KeyPath<J.M, Relation>) -> Self where Relation : EagerLoadable, J.M == Relation.From {
        queryBuilder.with(relationKey)
        return self
    }

    // periphery:ignore
    @discardableResult func with<Relation>(_ throughKey: KeyPath<J.M, Relation>, _ nested: (NestedEagerLoadBuilder<QueryBuilder<J.M>, Relation>) -> ()) -> Self where Relation : EagerLoadable, J.M == Relation.From {
        queryBuilder.with(throughKey, nested)
        return self
    }

    @discardableResult
    func field<Field>(_ field: KeyPath<J.M, Field>) -> Self where Field: QueryableProperty, Field.Model == J.M {
        queryBuilder.field(field)
        return self
    }

    @discardableResult
    func field<Joined, Field>(_ joined: Joined.Type, _ field: KeyPath<Joined, Field>) -> Self where Joined: Schema, Field: QueryableProperty, Field.Model == Joined {
        queryBuilder.field(joined, field)
        return self
    }

    @discardableResult func fields<Joined>(for model: Joined.Type) -> Self where Joined : Schema {
        queryBuilder.fields(for: model)
        return self
    }

    @discardableResult func unique() -> Self {
        queryBuilder.unique()
        return self
    }

    @discardableResult func limit(_ count: Int) -> Self {
        queryBuilder.limit(count)
        return self
    }

    func all() async throws -> [J] {
        try await queryBuilder.all()
            .map(J.init(model:))
    }

    func all() -> EventLoopFuture<[J]> {
        queryBuilder.all()
            .mapEach(J.init(model:))
    }

    func first() async throws -> J? {
        try await queryBuilder.first()
            .map(J.init(model:))
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

    func serialize(_ processSQL: ((sql: String, binds: [any Encodable])) -> Void) -> Self {
        _ = queryBuilder.serialize(processSQL)
        return self
    }

}

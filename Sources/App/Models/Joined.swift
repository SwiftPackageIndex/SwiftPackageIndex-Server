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

struct Joined<M: Model, R1: Model, R2: Model> {
    private(set) var model: M
}

extension Joined {

    /// JoinedQueryBuilder is a wrapper around QueryBuilder to allow Joined to be used like a Model query without actually being a Model
    struct JoinedQueryBuilder {
        var queryBuilder: QueryBuilder<M>

        @discardableResult
        func filter(_ field: DatabaseQuery.Field, _ method: DatabaseQuery.Filter.Method, _ value: DatabaseQuery.Value) -> Self {
            queryBuilder.filter(field, method, value)
            return self
        }

        @discardableResult func filter<Joined>(_ schema: Joined.Type, _ filter: ModelValueFilter<Joined>) -> Self where Joined : Schema {
            queryBuilder.filter(schema, filter)
            return self
        }

        func sort<Field>(_ field: KeyPath<M, Field>, _ direction: DatabaseQuery.Sort.Direction = .ascending) -> Self where M == Field.Model, Field : QueryableProperty {
            // TODO: check that this sorts correctly
            _ = queryBuilder.sort(field, direction)
            return self
        }

        func all() -> EventLoopFuture<[Joined<M, R1, R2>]> {
            queryBuilder.all()
                .mapEach(Joined.init(model:))
        }

        func first() -> EventLoopFuture<Joined<M, R1, R2>?> {
            queryBuilder.first()
                .optionalMap(Joined.init(model:))
        }
    }

    static func query<V1: Codable, V2: Codable>(
        on database: Database,
        _ joinFilter1: JoinFilter<R1, M, V1>,
        _ joinFilter2: JoinFilter<R2, M, V2>) -> JoinedQueryBuilder {
            .init(queryBuilder: M.query(on: database)
                    .join(R1.self, on: joinFilter1)
                    .join(R2.self, on: joinFilter2))
    }

    var relation1: R1? { try? model.joined(R1.self) }

    var relation2: R2? { try? model.joined(R2.self) }

}


extension Joined where M == Package, R1 == Repository, R2 == Version {
    var repository: Repository? { relation1 }
    var version: Version? { relation2 }

    static func query(on database: Database) -> JoinedQueryBuilder {
        query(on: database,
              \Repository.$package.$id == \Package.$id,
              \Version.$package.$id == \Package.$id)
    }
}

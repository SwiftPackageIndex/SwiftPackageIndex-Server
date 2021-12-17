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

// TODO: move
protocol Joinable: Schema {}
extension Package: Joinable {}
extension Repository: Joinable {}
extension Version: Joinable {}
extension DefaultVersion: Joinable {}
extension ReleaseVersion: Joinable {}
extension PreReleaseVersion: Joinable {}


struct Joined5<M: Model, R1: Joinable, R2: Joinable, R3: Joinable, R4: Joinable>: ModelInitializable {
    private(set) var model: M
}


extension Joined5 {
    /// Query method that joins R1, R2, R3, and R4 on M via the given join filters.
    /// - Returns: a `JoinedQueryBuilder<Self>`
    static func query<V1: Codable, V2: Codable, V3: Codable, V4: Codable,
                      L1: Schema, L2: Schema, L3: Schema, L4: Schema>(
                        on database: Database,
                        join joinFilter1: JoinFilter<R1, L1, V1>,
                        method method1: DatabaseQuery.Join.Method = .inner,
                        join joinFilter2: JoinFilter<R2, L2, V2>,
                        method method2: DatabaseQuery.Join.Method = .inner,
                        join joinFilter3: JoinFilter<R3, L3, V3>,
                        method method3: DatabaseQuery.Join.Method = .inner,
                        join joinFilter4: JoinFilter<R4, L4, V4>,
                        method method4: DatabaseQuery.Join.Method = .inner
                      ) -> JoinedQueryBuilder<Joined5> {
            .init(
                queryBuilder: M.query(on: database)
                    .join(R1.self, on: joinFilter1, method: method1)
                    .join(R2.self, on: joinFilter2, method: method2)
                    .join(R3.self, on: joinFilter3, method: method3)
                    .join(R4.self, on: joinFilter4, method: method4)
            )
    }

    var relation1: R1? { try? model.joined(R1.self) }
    var relation2: R2? { try? model.joined(R2.self) }
    var relation3: R3? { try? model.joined(R3.self) }
    var relation4: R4? { try? model.joined(R4.self) }
}

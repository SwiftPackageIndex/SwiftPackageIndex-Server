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

import FluentSQL


extension QueryBuilder {
    struct DummyConverterDelegate: SQLConverterDelegate {
        func customDataType(_ dataType: DatabaseSchema.DataType) -> (any SQLExpression)? { nil }
    }

    func serialize(_ processSQL: (String) -> Void) -> Self {
        guard let sqlDb = database as? SQLDatabase else { return self }
        let expr = SQLQueryConverter(delegate: DummyConverterDelegate()).convert(query)
        processSQL(sqlDb.serialize(expr).sql)
        return self
    }
}

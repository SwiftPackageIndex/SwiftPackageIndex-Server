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

import SQLKit


// MARK: - SQL Functions

func any(_ array: SQLExpression) -> SQLFunction {
    SQLFunction("ANY", args: array)
}


func arrayToString(_ array: SQLExpression, delimiter: String) -> SQLFunction {
    SQLFunction("ARRAY_TO_STRING", args: array, SQLLiteral.string(delimiter))
}


func concat(with separator: String, _ args: SQLExpression...) -> SQLFunction {
    SQLFunction("CONCAT_WS", args: [SQLLiteral.string(separator)] + args)
}


func coalesce(_ args: SQLExpression...) -> SQLFunction {
    SQLFunction("COALESCE", args: args)
}


func lower(_ arg: SQLExpression) -> SQLFunction {
    SQLFunction("LOWER", args: arg)
}


func unnest(_ array: SQLExpression) -> SQLFunction {
    SQLFunction("UNNEST", args: array)
}

func plainto_tsquery(_ array: SQLExpression) -> SQLFunction {
    // generates a simplistic tsquery concatenating all individual words as
    // 'AND' tokens for the ts_query binary search structure. For example,
    // an input of 'bezier curve' becomes 'bezier & curve'.
    SQLFunction("plainto_tsquery", args: array)
}

func ts_rank(vector: SQLExpression, query: SQLExpression) -> SQLFunction {
    // returns a ranking value when applying the query to the relevant
    // tsvector data type. If the query wouldn't match at all, the ranking
    // returns as `0`. The documentation for the return values is non-specific
    // about the range, but hints that values can easily exceed 1.0. In
    // my experimentation, and based on reading the code at
    // https://github.com/postgres/postgres/blob/master/src/backend/utils/adt/tsrank.c
    // the returned rank values range from 0 to 1.0, with a single query term
    // perfectly matching the response returning a ranking of 0.6. Additional
    // query terms adjust the ranking - OR queries maintain or reduce the value
    // depending on matches with the vector, and AND queries increase the value
    // pressing it slowly up towards 1.0.
    SQLFunction("ts_rank", args: [vector, query])
}

// MARK: - SQL Binary Expressions

func isNotNull(_ column: SQLIdentifier) -> SQLBinaryExpression {
    SQLBinaryExpression(left: column, op: SQLBinaryOperator.isNot, right: SQLRaw("NULL"))
}

func eq(_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLBinaryExpression {
    SQLBinaryExpression(left: lhs, op: SQLBinaryOperator.equal, right: rhs)
}

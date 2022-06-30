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

import SQLKit


// MARK: - SQL Functions

func any(_ array: SQLExpression) -> SQLFunction {
    SQLFunction("ANY", args: array)
}

func arrayToString(_ array: SQLExpression, delimiter: String) -> SQLFunction {
    SQLFunction("ARRAY_TO_STRING", args: array, SQLLiteral.string(delimiter))
}

func concat(_ args: SQLExpression...) -> SQLFunction {
    SQLFunction("CONCAT", args: args)
}


func concat(with separator: String, _ args: SQLExpression...) -> SQLFunction {
    SQLFunction("CONCAT_WS", args: [SQLLiteral.string(separator)] + args)
}


func count(_ args: SQLExpression...) -> SQLFunction {
    SQLFunction("COUNT", args: args)
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

func to_tsvector(_ array: SQLExpression) -> SQLFunction {
    SQLFunction("to_tsvector", args: array)
}

func to_tsquery(_ array: SQLExpression) -> SQLFunction {
    SQLFunction("to_tsquery", args: array)
}

// MARK: - SQL Binary Expressions

func isNotNull(_ column: SQLIdentifier) -> SQLBinaryExpression {
    SQLBinaryExpression(left: column, op: SQLBinaryOperator.isNot, right: SQLRaw("NULL"))
}

func eq(_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLBinaryExpression {
    SQLBinaryExpression(left: lhs, op: SQLBinaryOperator.equal, right: rhs)
}


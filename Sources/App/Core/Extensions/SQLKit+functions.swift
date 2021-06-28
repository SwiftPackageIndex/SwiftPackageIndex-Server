import SQLKit


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


func isNotNull(_ column: SQLIdentifier) -> SQLBinaryExpression {
    SQLBinaryExpression(left: column, op: SQLBinaryOperator.isNot, right: SQLRaw("NULL"))
}


func eq(_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLBinaryExpression {
    SQLBinaryExpression(left: lhs, op: SQLBinaryOperator.equal, right: rhs)
}


import SQLKit


func concat(_ args: SQLExpression...) -> SQLFunction {
    SQLFunction("concat", args: args)
}


func count(_ args: SQLExpression...) -> SQLFunction {
    SQLFunction("count", args: args)
}


func coalesce(_ args: SQLExpression...) -> SQLFunction {
    SQLFunction("coalesce", args: args)
}


func lower(_ arg: SQLExpression) -> SQLFunction {
    SQLFunction("lower", args: arg)
}


func isNotNull(_ column: SQLIdentifier) -> SQLBinaryExpression {
    SQLBinaryExpression(left: column, op: SQLBinaryOperator.isNot, right: SQLRaw("NULL"))
}


func eq(_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLBinaryExpression {
    SQLBinaryExpression(left: lhs, op: SQLBinaryOperator.equal, right: rhs)
}


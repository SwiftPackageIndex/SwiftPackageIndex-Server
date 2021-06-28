import SQLKit


extension SQLOrderBy {
    init(_ expression: SQLExpression, _ direction: SQLDirection) {
        self.init(expression: expression, direction: direction)
    }

    func then(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> SQLOrderByGroup {
        SQLOrderByGroup([self, SQLOrderBy(expression, direction)])
    }
}

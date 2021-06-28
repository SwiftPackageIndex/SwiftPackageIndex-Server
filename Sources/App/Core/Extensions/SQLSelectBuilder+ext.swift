import SQLKit


extension SQLSelectBuilder {
    // sas 2020-06-05: workaround `direction: SQLExpression` signature in SQLKit
    // (should be SQLDirection)
    func orderBy(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> Self {
        return self.orderBy(SQLOrderBy(expression: expression, direction: direction))
    }

    func column(_ matchType: Search.MatchType) -> Self {
        column(matchType.sqlAlias)
    }

    func column(_ expression: SQLExpression, as alias: SQLExpression) -> Self {
        column(SQLAlias(expression, as: alias))
    }

    func column(_ expression: SQLExpression, as alias: String) -> Self {
        column(SQLAlias(expression, as: SQLIdentifier(alias)))
    }
}

import SQLKit


public struct SQLOrderByGroup: SQLExpression {
    public let orderByClauses: [SQLOrderBy]

    public init(_ orderby: SQLOrderBy...) {
        self.orderByClauses = orderby
    }

    public init(_ orderby: [SQLOrderBy]) {
        self.orderByClauses = orderby
    }

    public func serialize(to serializer: inout SQLSerializer) {
        guard let first = orderByClauses.first else { return }
        first.serialize(to: &serializer)
        for clause in orderByClauses.dropFirst() {
            serializer.write(", ")
            clause.serialize(to: &serializer)
        }
    }

    func then(_ expression: SQLExpression, _ direction: SQLDirection = .ascending) -> Self {
        SQLOrderByGroup(orderByClauses + [SQLOrderBy(expression, direction)])
    }
}

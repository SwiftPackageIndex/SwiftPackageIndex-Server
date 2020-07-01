import Fluent


extension Array where Element: FluentKit.Model {
    public func save(on database: Database) -> EventLoopFuture<Void> {
        map {
            $0.save(on: database)
        }.flatten(on: database.eventLoop)
    }
    
    public func update(on database: Database) -> EventLoopFuture<Void> {
        map {
            $0.update(on: database)
        }.flatten(on: database.eventLoop)
    }
}

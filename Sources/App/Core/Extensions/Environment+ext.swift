import Vapor

extension Environment {
    static var current: Self {
        (try? Environment.detect()) ?? .development
    }
}

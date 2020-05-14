import Vapor


enum API {
    struct Version: Content, Equatable {
        var version: String
    }
}

extension API {
    struct PostBuildTriggerDTO: Codable {
        var platform: Build.Platform
        var swiftVersion: SwiftVersion
    }

    struct PostCreateBuildDTO: Codable {
        var buildCommand: String?
        var logs: String?
        var logUrl: String?
        var platform: Build.Platform
        var status: Build.Status
        var swiftVersion: SwiftVersion
    }
}

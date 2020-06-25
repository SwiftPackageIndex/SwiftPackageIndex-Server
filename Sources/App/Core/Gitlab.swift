import Vapor


enum Gitlab {
    
    enum Error: LocalizedError {
        case missingToken
    }
    
    enum Builder {
        
        static let branch = "main"
        static let projectId = 19564054
        static var projectURL: String { "https://gitlab.com/api/v4/projects/\(projectId)" }
        
        static func postTrigger(client: Client,
                                versionID: Version.Id,
                                cloneURL: String,
                                platform: Build.Platform? = nil,
                                swiftVersion: SwiftVersion) -> EventLoopFuture<ClientResponse> {
            guard let pipelineToken = Current.gitlabPipelineToken(),
                  let builderToken = Current.builderToken()
            else { return client.eventLoop.future(error: Error.missingToken) }
            
            let uri: URI = .init(string: "\(projectURL)/trigger/pipeline")
            let req = client
                .post(uri) { req in
                    var data: [String: String] = [
                        "token": pipelineToken,
                        "ref": branch,
                        "variables[API_BASEURL]": SiteURL.apiBaseURL,
                        "variables[BUILDER_TOKEN]": builderToken,
                        "variables[CLONE_URL]": cloneURL,
                        "variables[SWIFT_MAJOR_VERSION]": "\(swiftVersion.major)",
                        "variables[SWIFT_MINOR_VERSION]": "\(swiftVersion.minor)",
                        "variables[SWIFT_PATCH_VERSION]": "\(swiftVersion.patch)",
                        "variables[VERSION_ID]": versionID.uuidString,
                    ]
                    if let platform = platform {
                        data["variables[PLATFORM]"] = "\(platform)"
                    }
                    try req.query.encode(data)
                }
            return req
        }

    }
}

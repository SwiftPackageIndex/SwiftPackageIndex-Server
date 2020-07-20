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
                                buildTool: BuildTool,
                                cloneURL: String,
                                platform: Build.Platform,
                                reference: Reference,
                                swiftVersion: SwiftVersion,
                                versionID: Version.Id) -> EventLoopFuture<ClientResponse> {
            guard let pipelineToken = Current.gitlabPipelineToken(),
                  let builderToken = Current.builderToken()
            else { return client.eventLoop.future(error: Error.missingToken) }
            
            let uri: URI = .init(string: "\(projectURL)/trigger/pipeline")
            let req = client
                .post(uri) { req in
                    let data: [String: String] = [
                        "token": pipelineToken,
                        "ref": branch,
                        "variables[API_BASEURL]": SiteURL.apiBaseURL,
                        "variables[BUILD_TOOL]": buildTool.rawValue,
                        "variables[BUILDER_TOKEN]": builderToken,
                        "variables[CLONE_URL]": cloneURL,
                        "variables[PLATFORM_NAME]": platform.name.rawValue,
                        "variables[PLATFORM_VERSION]": platform.version,
                        "variables[REFERENCE]": "\(reference)",
                        "variables[SWIFT_VERSION]": "\(swiftVersion)",
                        "variables[VERSION_ID]": versionID.uuidString,
                    ]
                    try req.query.encode(data)
                }
            return req
        }
        
    }
}

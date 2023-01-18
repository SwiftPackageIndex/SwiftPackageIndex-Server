// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor


enum Gitlab {

    static let baseURL = "https://gitlab.com/api/v4"

    enum Error: LocalizedError {
        case missingConfiguration(String)
        case missingToken
        case requestFailed(HTTPStatus, URI)
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
        return d
    }()

}


// MARK: - Build specific constants


extension Gitlab {

    enum Builder {
        /// swiftpackageindex-builder project id
        static let projectId = 19564054
        static var projectURL: String { "\(Gitlab.baseURL)/projects/\(projectId)" }
    }

}


// MARK: - Builder pipeline triggers


extension Gitlab.Builder {

#if DEBUG
    static var branch = "main"
#else
    static let branch = "main"
#endif

    struct Response: Content, Codable {
        var webUrl: String

        enum CodingKeys: String, CodingKey {
            case webUrl = "web_url"
        }
    }

    static func triggerBuild(client: Client,
                             logger: Logger,
                             buildId: Build.Id,
                             cloneURL: String,
                             platform: Build.Platform,
                             reference: Reference,
                             swiftVersion: SwiftVersion,
                             versionID: Version.Id) -> EventLoopFuture<Build.TriggerResponse> {
        guard let pipelineToken = Current.gitlabPipelineToken(),
              let builderToken = Current.builderToken()
        else { return client.eventLoop.future(error: Gitlab.Error.missingToken) }
        guard let awsDocsBucket = Current.awsDocsBucket() else {
            return client.eventLoop.future(error: Gitlab.Error.missingConfiguration("AWS_DOCS_BUCKET"))
        }

        let uri: URI = .init(string: "\(projectURL)/trigger/pipeline")
        let req = client
            .post(uri) { req in
                let data = PostDTO(
                    token: pipelineToken,
                    ref: branch,
                    variables: [
                        "API_BASEURL": SiteURL.apiBaseURL,
                        "AWS_DOCS_BUCKET": awsDocsBucket,
                        "BUILD_ID": buildId.uuidString,
                        "BUILD_PLATFORM": platform.rawValue,
                        "BUILDER_TOKEN": builderToken,
                        "CLONE_URL": cloneURL,
                        "REFERENCE": "\(reference)",
                        "SWIFT_VERSION": "\(swiftVersion.major).\(swiftVersion.minor)",
                        "VERSION_ID": versionID.uuidString
                    ])
                try req.query.encode(data)
            }
        return req.map { response in
            do {
                let res = Build.TriggerResponse(
                    status: response.status,
                    webUrl: try response.content.decode(Response.self).webUrl
                )
                logger.info("Triggered build \(buildId) \(res.webUrl)")
                return res
            } catch {
                let body = response.body?.asString() ?? "nil"
                logger.error("Trigger failed: \(cloneURL) @ \(reference), \(platform) / \(swiftVersion), \(versionID), status: \(response.status), body: \(body)")
                return .init(status: response.status, webUrl: nil)
            }
        }
    }

    struct PostDTO: Codable, Equatable {
        var token: String
        var ref: String
        var variables: [String: String]
    }

}


// MARK: - Builder pipeline queries


extension Gitlab.Builder {

    enum Status: String, Decodable {
        case canceled
        case created
        case failed
        case manual
        case pending
        case running
        case skipped
        case success
    }

    // periphery:ignore
    struct Pipeline: Decodable {
        var id: Int
        var status: Status
    }

    // https://docs.gitlab.com/ee/api/pipelines.html
    static func fetchPipelines(client: Client,
                               status: Status,
                               page: Int,
                               pageSize: Int = 20) -> EventLoopFuture<[Pipeline]> {
        guard let apiToken = Current.gitlabApiToken()
        else { return client.eventLoop.future(error: Gitlab.Error.missingToken) }

        let uri: URI = .init(string: "\(projectURL)/pipelines?status=\(status)&page=\(page)&per_page=\(pageSize)")
        return client
            .get(uri, headers: HTTPHeaders([("Authorization", "Bearer \(apiToken)")]))
            .flatMap { response -> EventLoopFuture<[Pipeline]> in
                guard response.status == .ok else {
                    return client.eventLoop.future(error: Gitlab.Error.requestFailed(response.status, uri))
                }
                do {
                    let res = try response.content.decode([Pipeline].self, using: Gitlab.decoder)
                    return client.eventLoop.future(res)
                } catch {
                    return client.eventLoop.future(error: error)
                }
            }
    }

    static func getStatusCount(client: Client,
                               status: Status,
                               page: Int = 1,
                               pageSize: Int = 20,
                               maxPageCount: Int = 5) -> EventLoopFuture<Int> {
        fetchPipelines(client: client, status: status, page: page, pageSize: pageSize)
            .map(\.count)
            .flatMap { count -> EventLoopFuture<Int> in
                if count == pageSize && page < maxPageCount {
                    return getStatusCount(client: client,
                                          status: status,
                                          page: page + 1,
                                          pageSize: pageSize,
                                          maxPageCount: maxPageCount)
                        .map { count + $0 }
                } else {
                    return client.eventLoop.future(count)
                }
            }
    }

}


private extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}


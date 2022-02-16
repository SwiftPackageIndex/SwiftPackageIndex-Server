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

    static let branch = "main"

    struct Response: Content, Codable {
        var webUrl: String

        enum CodingKeys: String, CodingKey {
            case webUrl = "web_url"
        }
    }

    static func triggerBuild(client: Client,
                             buildId: Build.Id,
                             cloneURL: String,
                             platform: Build.Platform,
                             reference: Reference,
                             swiftVersion: SwiftVersion,
                             versionID: Version.Id) -> EventLoopFuture<Build.TriggerResponse> {
        guard let pipelineToken = Current.gitlabPipelineToken(),
              let builderToken = Current.builderToken()
        else { return client.eventLoop.future(error: Gitlab.Error.missingToken) }

        let uri: URI = .init(string: "\(projectURL)/trigger/pipeline")
        let req = client
            .post(uri) { req in
                let data = PostDTO(
                    token: pipelineToken,
                    ref: branch,
                    variables: [
                        "API_BASEURL": SiteURL.apiBaseURL,
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
        return req.flatMapThrowing {
            ($0.status, try $0.content.decode(Response.self).webUrl)
        }
        .map(Build.TriggerResponse.init(status:webUrl:))
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


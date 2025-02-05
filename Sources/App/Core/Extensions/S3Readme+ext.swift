// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Dependencies
import S3Store
import Vapor


extension S3Readme {
    enum Error: Swift.Error {
        case envVariableNotSet(String)
        case invalidURL(String)
        case missingBody
        case requestFailed(key: S3Store.Key, error: Swift.Error)
        case storeReadmeFailed
        case storeImagesFailed
    }

    static func fetchReadme(owner: String, repository: String) async throws(S3Readme.Error) -> String {
        let key = try S3Store.Key.readme(owner: owner, repository: repository)
        @Dependency(\.httpClient) var httpClient
        let response: HTTPClient.Response
        do {
            response = try await httpClient.get(url: key.objectUrl)
        } catch {
            throw .requestFailed(key: key, error: error)
        }
        guard let body = response.body else { throw .missingBody }
        return body.asString()
    }

    static func storeReadme(owner: String, repository: String, readme: String) async throws(S3Readme.Error) -> String {
        @Dependency(\.environment) var environment
        @Dependency(\.logger) var logger

        guard let accessKeyId = environment.awsAccessKeyId() else { throw .envVariableNotSet("AWS_ACCESS_KEY_ID") }
        guard let secretAccessKey = environment.awsSecretAccessKey() else { throw .envVariableNotSet("AWS_SECRET_ACCESS_KEY")}
        let store = S3Store(credentials: .init(keyId: accessKeyId, secret: secretAccessKey))
        let key = try S3Store.Key.readme(owner: owner, repository: repository)

        logger.debug("Copying readme to \(key.s3Uri) ...")
        do {
            try await store.save(payload: readme, to: key)
        } catch {
            throw .requestFailed(key: key, error: error)
        }

        return key.objectUrl
    }

    static func storeReadmeImages(imagesToCache: [Github.Readme.ImageToCache]) async throws(S3Readme.Error) {
        @Dependency(\.environment) var environment
        @Dependency(\.httpClient) var httpClient
        @Dependency(\.logger) var logger

        guard let accessKeyId = environment.awsAccessKeyId() else { throw .envVariableNotSet("AWS_ACCESS_KEY_ID") }
        guard let secretAccessKey = environment.awsSecretAccessKey() else { throw .envVariableNotSet("AWS_SECRET_ACCESS_KEY")}

        let store = S3Store(credentials: .init(keyId: accessKeyId, secret: secretAccessKey))
        for imageToCache in imagesToCache {
            logger.debug("Copying readme image to \(imageToCache.s3Key.s3Uri) ...")
            do {
                let response = try await httpClient.get(url: imageToCache.originalUrl)
                if var body = response.body, let imageData = body.readData(length: body.readableBytes) {
                    try await store.save(payload: imageData, to: imageToCache.s3Key)
                }
            } catch {
                throw .requestFailed(key: imageToCache.s3Key, error: error)
            }
        }
    }

}

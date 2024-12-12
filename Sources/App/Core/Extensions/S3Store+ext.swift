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

import S3Store
import Vapor
import Dependencies


extension S3Readme {
    enum Error: Swift.Error {
        case envVariableNotSet(String)
        case invalidURL(String)
        case missingBody
        case requestFailed(key: S3Store.Key, error: Swift.Error)
        case storeReadmeFailed
        case storeImagesFailed
    }

    static func fetchReadme(client: Client, owner: String, repository: String) async throws(S3Readme.Error) -> String {
        let key = try S3Store.Key.readme(owner: owner, repository: repository)
        let response: ClientResponse
        do {
            response = try await client.get(URI(string: key.objectUrl))
        } catch {
            throw .requestFailed(key: key, error: error)
        }
        guard let body = response.body else { throw .missingBody }
        return body.asString()
    }

    static func storeReadme(owner: String, repository: String, readme: String) async throws(S3Readme.Error) -> String {
        @Dependency(\.environment) var environment
        guard let accessKeyId = environment.awsAccessKeyId() else { throw .envVariableNotSet("AWS_ACCESS_KEY_ID") }
        guard let secretAccessKey = environment.awsSecretAccessKey() else { throw .envVariableNotSet("AWS_SECRET_ACCESS_KEY")}
        let store = S3Store(credentials: .init(keyId: accessKeyId, secret: secretAccessKey))
        let key = try S3Store.Key.readme(owner: owner, repository: repository)

        Current.logger().debug("Copying readme to \(key.s3Uri) ...")
        do {
            try await store.save(payload: readme, to: key)
        } catch {
            throw .requestFailed(key: key, error: error)
        }

        return key.objectUrl
    }

    static func storeReadmeImages(client: Client, imagesToCache: [Github.Readme.ImageToCache]) async throws(S3Readme.Error) {
        @Dependency(\.environment) var environment
        guard let accessKeyId = environment.awsAccessKeyId() else { throw .envVariableNotSet("AWS_ACCESS_KEY_ID") }
        guard let secretAccessKey = environment.awsSecretAccessKey() else { throw .envVariableNotSet("AWS_SECRET_ACCESS_KEY")}

        let store = S3Store(credentials: .init(keyId: accessKeyId, secret: secretAccessKey))
        for imageToCache in imagesToCache {
            Current.logger().debug("Copying readme image to \(imageToCache.s3Key.s3Uri) ...")
            do {
                let response = try await client.get(URI(stringLiteral: imageToCache.originalUrl))
                if var body = response.body, let imageData = body.readData(length: body.readableBytes) {
                    try await store.save(payload: imageData, to: imageToCache.s3Key)
                }
            } catch {
                throw .requestFailed(key: imageToCache.s3Key, error: error)
            }
        }
    }

}


extension S3Store.Key {
    static func readme(owner: String, repository: String, imageUrl: String? = nil) throws(S3Readme.Error) -> Self {
        @Dependency(\.environment) var environment
        guard let bucket = environment.awsReadmeBucket() else { throw .envVariableNotSet("AWS_README_BUCKET") }

        if let imageUrl {
            guard let url = URL(string: imageUrl) else { throw .invalidURL(imageUrl) }
            let filename = url.lastPathComponent
            let path = "\(owner)/\(repository)/\(filename)".lowercased()
            return .init(bucket: bucket, path: path)
        } else {
            let path = "\(owner)/\(repository)/readme.html".lowercased()
            return .init(bucket: bucket, path: path)
        }
    }
}

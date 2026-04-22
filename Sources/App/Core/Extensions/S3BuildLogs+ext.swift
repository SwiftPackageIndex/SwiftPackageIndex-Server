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
import Foundation
import S3Store
import Vapor


extension S3BuildLogs {
    enum Error: Swift.Error {
        case envVariableNotSet(String)
        case missingBucket
        case preSignedURLGenerationFailed(Swift.Error)
    }

    static func generatePreSignedURL(buildId: Build.Id) async throws(S3BuildLogs.Error) -> String {
        @Dependency(\.environment) var environment
        @Dependency(\.logger) var logger
        @Dependency(\.uuid) var uuid

        guard let bucket = environment.awsBuildLogsBucket() else {
            throw .envVariableNotSet("AWS_BUILD_LOGS_BUCKET")
        }

        // Use bucket-specific region, fallback to general AWS region, then default
        let region = environment.awsBuildLogsBucketRegion() ?? environment.awsRegion() ?? "us-east-2"

        let store: S3Store
        if environment.awsUseIamRole() {
            store = S3Store(region: region)
        } else {
            guard let accessKeyId = environment.awsAccessKeyId() else {
                throw .envVariableNotSet("AWS_ACCESS_KEY_ID")
            }
            guard let secretAccessKey = environment.awsSecretAccessKey() else {
                throw .envVariableNotSet("AWS_SECRET_ACCESS_KEY")
            }
            store = S3Store(credentials: .init(keyId: accessKeyId, secret: secretAccessKey), region: region)
        }

        // Generate a UUID for the log file as specified in the requirements
        let logUUID = uuid()
        let path = "\(logUUID.uuidString).log"
        let key = S3Store.Key(bucket: bucket, path: path)
        let expiration = TimeInterval(environment.packageUploadPreSignedURLExpiration())

        do {
            // Create an empty log file first to ensure the object exists
            let emptyLogContent = Data()
            try await store.save(payload: emptyLogContent, to: key)

            let preSignedURL = try await store.generatePreSignedURL(for: key, expiration: expiration)
            return preSignedURL
        } catch {
            logger.error("Failed to create log file or generate pre-signed URL for build logs \(buildId): \(error)")
            throw .preSignedURLGenerationFailed(error)
        }
    }
}

enum S3BuildLogs {
    // This enum serves as a namespace for S3 build logs functionality
}
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


extension S3PackageBuilds {
    enum Error: Swift.Error {
        case envVariableNotSet(String)
        case missingBucket
        case preSignedURLGenerationFailed(Swift.Error)
    }

    static func generatePreSignedURL(buildId: Build.Id,
                                   packageName: String,
                                   owner: String,
                                   repository: String,
                                   reference: Reference) async throws(S3PackageBuilds.Error) -> String {
        @Dependency(\.environment) var environment
        @Dependency(\.logger) var logger

        guard let bucket = environment.awsDocsInboxBucket() else {
            logger.error("AWS_DOCS_INBOX_BUCKET environment variable not set")
            throw .envVariableNotSet("AWS_DOCS_INBOX_BUCKET")
        }

        // Use bucket-specific region, fallback to general AWS region, then default
        let region = environment.awsDocsInboxBucketRegion() ?? environment.awsRegion() ?? "us-east-2"

        let store: S3Store
        if environment.awsUseIamRole() {
            store = S3Store(region: region)
        } else {
            guard let accessKeyId = environment.awsAccessKeyId() else {
                logger.error("AWS_ACCESS_KEY_ID environment variable not set")
                throw .envVariableNotSet("AWS_ACCESS_KEY_ID")
            }
            guard let secretAccessKey = environment.awsSecretAccessKey() else {
                logger.error("AWS_SECRET_ACCESS_KEY environment variable not set")
                throw .envVariableNotSet("AWS_SECRET_ACCESS_KEY")
            }
            store = S3Store(credentials: .init(keyId: accessKeyId, secret: secretAccessKey), region: region)
        }

        // Construct path to match DocUploadBundle expected structure:
        // {owner}/{repository}/{reference}/{buildId}/{packageName}.zip
        let pathEncodedReference = reference.pathEncoded.lowercased()
        let path = "\(owner.lowercased())/\(repository.lowercased())/\(pathEncodedReference)/\(buildId.uuidString)/\(packageName).zip"
        let key = S3Store.Key(bucket: bucket, path: path)
        let expiration = TimeInterval(environment.packageUploadPreSignedURLExpiration())

        do {
            // Generate pre-signed URL without creating an empty file
            // The actual documentation zip will be uploaded by the build process if documentation is generated
            let preSignedURL = try await store.generatePreSignedURL(for: key, expiration: expiration)
            return preSignedURL
        } catch {
            logger.error("Failed to generate pre-signed URL for build \(buildId): \(error)")
            throw .preSignedURLGenerationFailed(error)
        }
    }
}

enum S3PackageBuilds {
    // This enum serves as a namespace for S3 package builds functionality
}
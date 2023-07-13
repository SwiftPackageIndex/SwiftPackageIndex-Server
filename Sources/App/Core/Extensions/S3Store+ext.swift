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


extension S3Store {

    static func fetchReadme(client: Client, owner: String, repository: String) async throws -> String {
        let key = try Key.readme(owner: owner, repository: repository)
        guard let body = try await client.get(URI(string: key.objectUrl)).body else {
            throw Error.genericError("No body")
        }
        return body.asString()
    }

    static func storeReadme(owner: String, repository: String, readme: String) async throws {
        guard let accessKeyId = Current.awsAccessKeyId(),
              let secretAccessKey = Current.awsSecretAccessKey()
        else {
            throw Error.genericError("missing AWS credentials")
        }
        let key = try Key.readme(owner: owner, repository: repository)

        try await Current.fileManager.withTempDir { tempDir in
            let tempfile = "\(tempDir)/readme.html"
            guard Current.fileManager.createFile(atPath: tempfile, contents: Data(readme.utf8)) else {
                throw Error.genericError("failed to save temporary readme")
            }

            let store = S3Store(credentials: .init(keyId: accessKeyId, secret: secretAccessKey))
            Current.logger().debug("Copying \(tempfile) to \(key.s3Uri) ...")
            try await store.copy(from: tempfile, to: key, logger: Current.logger())
        }
    }

}


extension S3Store.Key {
    static func readme(owner: String, repository: String) throws -> Self {
        guard let bucket = Current.awsReadmeBucket() else {
            throw S3Store.Error.genericError("AWS_README_BUCKET not set")
        }
        let path = "\(owner)/\(repository)/readme.html".lowercased()
        return .init(bucket: bucket, path: path)
    }
}

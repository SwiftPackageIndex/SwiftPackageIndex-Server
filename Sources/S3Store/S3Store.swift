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

import Foundation

import SotoS3
import SotoS3FileTransfer


public struct S3Store {
    static private let region: SotoS3.Region = .useast2
    
    private let credentials: Credentials
    
    public init(credentials: Credentials) {
        self.credentials = credentials
    }
    
    public func copy(from path: String, to key: Key, logger: Logger? = nil) async throws {
        guard let s3File = S3File(url: key.s3Uri) else { throw Error.invalidURL(key.s3Uri) }
        
        let client = AWSClient(
            credentialProvider: .static(accessKeyId: credentials.keyId,
                                        secretAccessKey: credentials.secret),
            httpClientProvider: .createNew
        )
        defer { try? client.syncShutdown() }
        let s3 = S3(client: client, region: Self.region)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)
        defer { try? s3FileTransfer.syncShutdown() }
        
        var nextProgressTick = 0.1
        try await s3FileTransfer.copy(from: path, to: s3File) { progress in
            if progress >= nextProgressTick {
                logger?.debug("Copying... [\(percent: progress)]")
                nextProgressTick += 0.1
            }
        }
    }
}

extension S3Store {
    public struct Credentials {
        public var keyId: String
        var secret: String

        public init(keyId: String, secret: String) {
            self.keyId = keyId
            self.secret = secret
        }
    }

    public struct Key {
        let bucket: String
        let path: String

        public init(bucket: String, path: String) {
            self.bucket = bucket
            self.path = path.droppingLeadingSlashes
        }

        public var objectUrl: String { "https://\(bucket).s3.\(S3Store.region).amazonaws.com/\(path)" }
        public var s3Uri: String { "s3://\(bucket)/\(path)" }
    }

    public enum Error: Swift.Error {
        case invalidURL(String)
        case genericError(String)
    }
}


private extension DefaultStringInterpolation {
    mutating func appendInterpolation(percent value: Double) {
        appendInterpolation(String(format: "%.0f%%", value * 100))
    }
}


private extension String {
    var droppingLeadingSlashes: String {
        var result = self[...]
        while result.hasPrefix("/") {
            result = result.dropFirst()
        }
        return String(result)
    }
}

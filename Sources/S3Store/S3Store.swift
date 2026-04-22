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


public struct S3Store {
    static private let defaultRegion: SotoS3.Region = .useast2
    private let region: SotoS3.Region
    private let credentials: Credentials?

    public init(credentials: Credentials, region: String? = nil) {
        self.credentials = credentials
        self.region = SotoS3.Region(rawValue: region ?? "us-east-2")
    }

    public init(region: String? = nil) {
        self.credentials = nil
        self.region = SotoS3.Region(rawValue: region ?? "us-east-2")
    }

    public func save(payload: String, to key: Key) async throws {
        try await save(payload: Data(payload.utf8), to: key)
    }

    public func save(payload: Data, to key: Key) async throws {
        let client: AWSClient
        if let credentials = credentials {
            client = AWSClient(credentialProvider: .static(accessKeyId: credentials.keyId, secretAccessKey: credentials.secret),
                              httpClientProvider: .createNew)
        } else {
            client = AWSClient(credentialProvider: .default,
                              httpClientProvider: .createNew)
        }
        do {
            let s3 = S3(client: client, region: self.region)
            let req = S3.PutObjectRequest(
                body: .data(payload),
                bucket: key.bucket,
                key: key.path
            )
            _ = try await s3.putObject(req)
            try await client.shutdown()
        } catch {
            try await client.shutdown()
            throw error
        }
    }

    public func generatePreSignedURL(for key: Key, expiration: TimeInterval = 3600) async throws -> String {
        let client: AWSClient
        if let credentials = credentials {
            client = AWSClient(credentialProvider: .static(accessKeyId: credentials.keyId, secretAccessKey: credentials.secret),
                              httpClientProvider: .createNew)
        } else {
            client = AWSClient(credentialProvider: .default,
                              httpClientProvider: .createNew)
        }
        defer {
            Task {
                try await client.shutdown()
            }
        }

        let s3 = S3(client: client, region: self.region)

        // Create the base URL for the S3 object
        let baseURL = URL(string: "https://\(key.bucket).s3.\(self.region).amazonaws.com/\(key.path)")!

        let url = try await s3.signURL(url: baseURL, httpMethod: .PUT, expires: .seconds(Int64(expiration)))
        return url.absoluteString
    }

    public func readString(from key: Key) async throws -> String {
        let client: AWSClient
        if let credentials = credentials {
            client = AWSClient(credentialProvider: .static(accessKeyId: credentials.keyId, secretAccessKey: credentials.secret),
                              httpClientProvider: .createNew)
        } else {
            client = AWSClient(credentialProvider: .default,
                              httpClientProvider: .createNew)
        }
        do {
            let s3 = S3(client: client, region: self.region)
            let req = S3.GetObjectRequest(
                bucket: key.bucket,
                key: key.path
            )
            let response = try await s3.getObject(req)
            try await client.shutdown()

            guard let body = response.body else {
                throw Error.genericError("No body in S3 response")
            }

            guard let string = body.asString() else {
                throw Error.genericError("Unable to decode S3 object as UTF-8 string")
            }

            return string
        } catch {
            try await client.shutdown()
            throw error
        }
    }

    public func readData(from key: Key) async throws -> Data {
        let client: AWSClient
        if let credentials = credentials {
            client = AWSClient(credentialProvider: .static(accessKeyId: credentials.keyId, secretAccessKey: credentials.secret),
                              httpClientProvider: .createNew)
        } else {
            client = AWSClient(credentialProvider: .default,
                              httpClientProvider: .createNew)
        }
        do {
            let s3 = S3(client: client, region: self.region)
            let req = S3.GetObjectRequest(
                bucket: key.bucket,
                key: key.path
            )
            let response = try await s3.getObject(req)
            try await client.shutdown()

            guard let body = response.body else {
                throw Error.genericError("No body in S3 response")
            }

            guard let byteBuffer = body.asByteBuffer() else {
                throw Error.genericError("Unable to convert S3 response body to ByteBuffer")
            }

            return Data(buffer: byteBuffer)
        } catch {
            try await client.shutdown()
            throw error
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

    public struct Key: Equatable, Sendable {
        public let bucket: String
        public let path: String
        public let region: SotoS3.Region

        public init(bucket: String, path: String, region: SotoS3.Region = .useast2) {
            self.bucket = bucket
            self.path = path.droppingLeadingSlashes
            self.region = region
        }

        public var objectUrl: String { "https://\(bucket).s3.\(region).amazonaws.com/\(path)" }
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

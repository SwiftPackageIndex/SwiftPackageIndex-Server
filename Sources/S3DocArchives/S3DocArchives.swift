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

import Foundation
import Parsing
import SotoS3


public struct DocArchive: Codable, Equatable {
    public var path: Path
    public var title: String

#if DEBUG
    // for unit testing purposes only
    internal init(path: Path, title: String) {
        self.path = path
        self.title = title
    }

    static func mock(_ owner: String = "foo",
                     _ repository: String = "bar",
                     _ ref: String = "ref",
                     _ product: String = "product",
                     _ title: String = "Product") -> Self {
        .init(path: .init(owner: owner, repository: repository, ref: ref, product: product),
              title: title)
    }
#endif

    init(s3: S3, in bucket: String, path: Path) async {
        self.path = path
        self.title = (try? await s3.getDocArchiveTitle(in: bucket, path: path)) ?? path.product
    }
}


public extension DocArchive {
    static func fetchAll(prefix: String,
                         awsBucketName: String,
                         awsAccessKeyId: String,
                         awsSecretAccessKey: String) async throws -> [DocArchive] {
        let key = S3.StoreKey(bucket: awsBucketName, path: prefix)
        let client = AWSClient(credentialProvider: .static(accessKeyId: awsAccessKeyId,
                                                           secretAccessKey: awsSecretAccessKey),
                               httpClientProvider: .createNew)
        defer { try? client.syncShutdown() }

        let s3 = S3(client: client, region: .useast2)

        // filter this down somewhat by eliminating `.json` files
        let paths = try await s3.listFiles(key: key, delimiter: ".json")
            .compactMap { try? path.parse($0.file.key) }

        var archives = [DocArchive]()
        for path in paths {
            archives.append(await DocArchive(s3: s3, in: awsBucketName, path: path))
        }

        return archives
    }
}


extension DocArchive {
    public struct Path: Codable, Equatable {
        public var owner: String
        public var repository: String
        public var ref: String
        public var product: String

        var s3path: String { "\(owner)/\(repository)/\(ref)" }
    }
}


extension DocArchive {
    struct DocumentationData: Codable, Equatable {
        var metadata: Metadata

        struct Metadata: Codable, Equatable {
            var title: String
        }
    }
}


// MARK: CustomStringConvertible

extension DocArchive: CustomStringConvertible {
    public var description: String {
        "\(path) - \(title)"
    }
}


extension DocArchive.Path: CustomStringConvertible {
    public var description: String {
        "\(owner)/\(repository) @ \(ref) - \(product)"
    }
}


// MARK: - Parsers

extension DocArchive {
    static let pathSegment = Parse {
        PrefixUpTo("/").map(.string)
        "/"
    }

    static let path = Parse(DocArchive.Path.init) {
        pathSegment
        pathSegment
        pathSegment
        "documentation/"
        pathSegment
        "index.html"
    }
}

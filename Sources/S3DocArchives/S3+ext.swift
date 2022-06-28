// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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


extension S3 {

    struct File {
        var bucket: String
        var key: String
    }

    struct FileDescriptor {
        let file: File
        let modificationDate: Date
        let size: Int
    }

    struct StoreKey {
        let bucket: String
        var path: String

        var url: String { "s3://\(bucket)/\(path)" }
    }

    func getFileContent(key: StoreKey) async throws -> Data? {
        let getObjectRequest = S3.GetObjectRequest(bucket: key.bucket, key: key.path)
        return try await self.getObject(getObjectRequest)
            .body?.asData()
    }

    func listFolders(key: StoreKey) -> EventLoopFuture<[String]> {
        let prefix = key.path.hasSuffix("/") ? key.path : key.path + "/"
        let bucket = key.bucket
        let request = S3.ListObjectsV2Request(bucket: bucket, delimiter: "/", prefix: prefix)
        return listObjectsV2Paginator(request, []) { accumulator, response, eventLoop in
            let prefixes = response.commonPrefixes?.compactMap(\.prefix) ?? []
            return eventLoop.makeSucceededFuture((true, accumulator + prefixes))
        }
    }

    func getDocArchiveTitle(in bucket: String,
                            path: DocArchive.Path) async throws -> String? {
        let key = S3.StoreKey(bucket: bucket,
                              path: path.s3path + "/data/documentation/\(path.product).json")
        guard let data = try await getFileContent(key: key) else { return nil }
        return try JSONDecoder().decode(DocArchive.DocumentationData.self, from: data)
            .metadata.title
    }

}


extension S3.File: CustomStringConvertible {
    var description: String {
        "s3://\(bucket)/\(key)"
    }
}


extension S3.FileDescriptor: CustomStringConvertible {
    var description: String {
        "\(file)"
    }
}

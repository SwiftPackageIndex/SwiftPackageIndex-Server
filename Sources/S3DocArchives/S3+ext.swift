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

    func listFiles(key: StoreKey, delimiter: String? = nil) async throws -> [FileDescriptor] {
        try await listFiles(key: key, delimiter: delimiter).get()
    }

    func listFiles(key: StoreKey, delimiter: String? = nil) -> EventLoopFuture<[FileDescriptor]> {
        let bucket = key.bucket
        let request = S3.ListObjectsV2Request(bucket: bucket, delimiter: delimiter, prefix: key.path)
        return listObjectsV2Paginator(request, []) { accumulator, response, eventLoop in
            let files: [FileDescriptor] = response.contents?.compactMap {
                guard let key = $0.key,
                      let lastModified = $0.lastModified,
                      let fileSize = $0.size else { return nil }
                return FileDescriptor(
                    file: File(bucket: bucket, key: key),
                    modificationDate: lastModified,
                    size: Int(fileSize)
                )
            } ?? []
            return eventLoop.makeSucceededFuture((true, accumulator + files))
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

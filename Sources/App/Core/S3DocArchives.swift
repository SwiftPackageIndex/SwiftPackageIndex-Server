import Foundation
import Parsing
import SotoS3


public enum S3DocArchives {

    public static func fetch(prefix: String,
                             awsBucketName: String,
                             awsAccessKeyId: String,
                             awsSecretAccessKey: String) async throws -> [DocArchive] {
        let key = S3.StoreKey(bucket: awsBucketName, directory: prefix)
        let client = AWSClient(credentialProvider: .static(accessKeyId: awsAccessKeyId,
                                                           secretAccessKey: awsSecretAccessKey),
                               httpClientProvider: .createNew)
        defer { try? client.syncShutdown() }

        let s3 = S3(client: client, region: .useast2)

        // filter this down somewhat by eliminating `.json` files
        return try await s3.listFiles(in: awsBucketName, key: key, delimiter: ".json")
            .compactMap { try? folder.parse($0.file.key) }
    }


    public struct DocArchive: CustomStringConvertible {
        var owner: String
        var repository: String
        var ref: String
        var product: String

        public var description: String {
            "\(owner)/\(repository) @ \(ref) - \(product)"
        }
    }


    static let pathSegment = Parse {
        PrefixUpTo("/").map(.string)
        "/"
    }


    static let folder = Parse(DocArchive.init) {
        pathSegment
        pathSegment
        pathSegment
        "documentation/"
        pathSegment
        "index.html"
    }

}


private extension S3 {
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
        let directory: String

        var filename: String { directory }
        var url: String { "s3://\(bucket)/\(filename)" }
    }


    func listFiles(in bucket: String, key: StoreKey, delimiter: String? = nil) async throws -> [FileDescriptor] {
        try await listFiles(in: bucket, key: key, delimiter: delimiter).get()
    }

    func listFiles(in bucket: String, key: StoreKey, delimiter: String? = nil) -> EventLoopFuture<[FileDescriptor]> {
        let request = S3.ListObjectsV2Request(bucket: bucket, delimiter: delimiter, prefix: key.filename)
        return self.listObjectsV2Paginator(request, []) { accumulator, response, eventLoop in
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
}



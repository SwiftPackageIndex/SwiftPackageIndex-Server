import Foundation


class TempDir {
    let path: String
    let fileManager: FileManager

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        path = tempDir.path
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        precondition(fileManager.fileExists(atPath: path), "failed to create temp dir")
    }

    deinit {
        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            print("⚠️ failed to delete temp directory: \(error.localizedDescription)")
        }
    }

    enum Error: LocalizedError {
        case invalidPath(String)
    }
}


func withTempDir<T>(body: (String) throws -> T) throws -> T {
    let tmp = try TempDir()
    return try body(tmp.path)
}

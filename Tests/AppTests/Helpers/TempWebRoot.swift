@testable import App

import Vapor


enum TempWebRoot {
    
    /// This is a temporary directory where we save the webpage to in prepartion for rendering into a web view. We use a temporary directory
    /// so if a test run crashes then the files will be cleaned up.
    private static var temporaryDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
    
    /// This is a constant which is added to the temporary directory URL in order to give us our own, clean, directory to be working in.
    private static var directoryName: String { "SPI-Server" }
    
    /// This is the Public/ directory as stored in the local copy of the repository.
    private static var publicDirectory: URL {
        URL(fileURLWithPath: DirectoryConfiguration.detect().workingDirectory + "Public/")
    }
    
    /// This is a constant for the name of the HTML file which is saved to before rendering in the web view.
    static var fileName: String { "index.html" }
    
    private static var fileManager: Foundation.FileManager { Foundation.FileManager.default }
    
    static func setup() {
        do {
            // 1. Remove the temporary directory if it already exists
            if fileManager.fileExists(atPath: baseURL.path) {
                // The temporary directory already exists, so let's clear it out...
                try fileManager.removeItem(at: baseURL)
            }
            
            // 2. Copy the Public/ directory to our temporary directory
            try fileManager.copyItem(at: publicDirectory, to: baseURL)
        } catch {
            print(error)
        }
        
    }
    
    static func cleanup() {
        let fileURL = baseURL.appendingPathComponent(TempWebRoot.fileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    static var baseURL: URL {
        temporaryDirectory.appendingPathComponent(directoryName)
    }
    
}

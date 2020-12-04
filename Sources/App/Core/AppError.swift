//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


enum AppError: LocalizedError {
    case envVariableNotSet(_ variable: String)
    case invalidPackageUrl(Package.Id?, _ url: String)
    case invalidPackageCachePath(Package.Id?, _ path: String)
    case invalidRevision(Version.Id?, _ revision: String?)
    case metadataRequestFailed(Package.Id?, HTTPStatus, URI)
    case noValidVersions(Package.Id?, _ url: String)
    case shellCommandFailed(_ command: String, _ path: String, _ message: String)
    
    case genericError(Package.Id?, _ message: String)
    
    var localizedDescription: String {
        switch self {
            case let .envVariableNotSet(value):
                return "Environment variable not set: \(value)"
            case let .invalidPackageUrl(id, value):
                return "Invalid packge URL: \(value) (id: \(id?.uuidString ?? "-"))"
            case let .invalidPackageCachePath(id, value):
                return "Invalid packge cache path: \(value) (id: \(id?.uuidString ?? "-")"
            case let .invalidRevision(id, value):
                return "Invalid revision: \(value ?? "nil") (id: \(id?.uuidString ?? "-"))"
            case let .metadataRequestFailed(id, status, uri):
                return "Metadata request for URI '\(uri.description)' failed with status '\(status)'  (id: \(id?.uuidString ?? "-"))"
            case let .noValidVersions(id, value):
                return "No valid version found for package '\(value)' (id: \(id?.uuidString ?? "-"))"
            case let .shellCommandFailed(command, path, message):
                return """
                    Shell command failed:
                    command: "\(command)"
                    path:    "\(path)"
                    message: "\(message)"
                    """
            case let .genericError(id, value):
                return "Generic error: \(value) (id: \(id?.uuidString ?? "-"))"
        }
    }
    
    var errorDescription: String? {
        localizedDescription
    }
    
    enum Level: String, Codable, CaseIterable {
        case critical
        case error
        case warning
        case info
        case debug
    }
}


extension AppError.Level: Comparable {
    static func < (lhs: AppError.Level, rhs: AppError.Level) -> Bool {
        allCases.firstIndex(of: lhs)! > allCases.firstIndex(of: rhs)!
    }
}


extension AppError {
    static func report(_ client: Client, _ level: Level, _ error: Error) -> EventLoopFuture<Void> {
        guard level >= Current.rollbarLogLevel() else { return client.eventLoop.future() }
        return Rollbar.createItem(client: client,
                                  level: .init(level: level),
                                  message: error.localizedDescription)
    }
}

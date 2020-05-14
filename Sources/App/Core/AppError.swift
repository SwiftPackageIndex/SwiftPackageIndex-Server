//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


enum AppError: LocalizedError {
    case envVariableNotSet(String)
    case invalidPackageUrl(Package.Id?, String)
    case invalidPackageCachePath(Package.Id?, String)
    case invalidRevision(Version.Id?, String?)
    case metadataRequestFailed(Package.Id?, HTTPStatus, URI)
    case genericError(Package.Id?, String)

    var localizedDescription: String {
        switch self {
            case let .envVariableNotSet(value):
                return "Environment variable not set: \(value)"
            case let .invalidPackageUrl(id, value):
                return "Invalid packge URL: \(value) (id: \(String(describing: id)))"
            case let .invalidPackageCachePath(id, value):
                return "Invalid packge cache path: \(value) (id: \(String(describing: id))"
            case let .invalidRevision(id, value):
                return "Invalid revision: \(value ?? "nil") (id: \(String(describing: id)))"
            case let .metadataRequestFailed(id, status, uri):
                return "Metadata request for URI '\(uri.description)' failed with status '\(status)'  (id: \(String(describing: id)))"
            case let .genericError(id, value):
                return "Generic error: \(value) (id: \(String(describing: id)))"
        }
    }

    var errorDescription: String? {
        localizedDescription
    }

    enum Level: String, Codable {
        case critical
        case error
        case warning
        case info
        case debug
    }
}


extension AppError {
    static func report(_ client: Client, _ level: Level, _ error: Error) -> EventLoopFuture<Void> {
        Rollbar.createItem(client: client,
                           level: .init(level: level),
                           message: error.localizedDescription)
    }
}

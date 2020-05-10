//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


enum AppError: LocalizedError {
    case invalidPackageUrl(Package.Id?, String)
    case invalidPackageCachePath(Package.Id?, String)
    case invalidRevision(Version.Id?, String?)
    case metadataRequestFailed(Package.Id?, HTTPStatus, URI)
    case genericError(Package.Id?, String)

    var localizedDescription: String {
        switch self {
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
}

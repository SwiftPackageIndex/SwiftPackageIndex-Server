//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


enum AppError: LocalizedError {
    case invalidPackageUrl(Package.Id?, String)  // TODO: perhaps rename `invalidPackage`
    case invalidRevision(Version.Id?, String?)
    case metadataRequestFailed(Package.Id?, HTTPStatus, URI)
    case genericError(Package.Id?, String)

    var localizedDescription: String {
        switch self {
            case let .invalidPackageUrl(id, value):
                return "Invalid packge URL: \(value) (id: \(id.map { "\($0)" } ?? "-"))"
            case let .invalidRevision(id, value):
                return "Invalid revision: \(value ?? "nil") (id: \(id.map { "\($0)" } ?? "-"))"
            case let .metadataRequestFailed(id, status, uri):
                return "Metadata request for URI '\(uri.description)' failed with status '\(status)'  (id: \(id.map { "\($0)" } ?? "-"))"
            case let .genericError(id, value):
                return "Generic error: \(value) (id: \(id.map { "\($0)" } ?? "-"))"
        }
    }

    var errorDescription: String? {
        localizedDescription
    }
}

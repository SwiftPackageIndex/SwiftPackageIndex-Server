//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


enum AppError: LocalizedError {
    case invalidPackageUrl(String)
    case metadataRequestFailed(HTTPStatus, URI)
    case genericError(String)

    var localizedDescription: String {
        switch self {
            case .invalidPackageUrl(let value):
                return "Invalid packge URL: \(value)"
            case let .metadataRequestFailed(status, uri):
                return "Metadata request for URI '\(uri.description)' failed with status '\(status)'"
            case .genericError(let value):
                return "Generic error: \(value)"
        }
    }

    var errorDescription: String? {
        localizedDescription
    }
}

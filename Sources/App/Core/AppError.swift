//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


enum AppError: Error {
    case invalidPackageUrl
    case requestFailed(HTTPStatus)
}

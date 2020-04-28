//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


enum Github {
    struct License: Decodable {
        var key: String
    }
    struct Parent: Decodable {
        var cloneUrl: String
        var fullName: String
        var url: String
    }
    struct Metadata: Decodable {
        var defaultBranch: String
        var description: String?
        var forksCount: Int
        var license: License?
        var stargazersCount: Int
        var parent: Parent?
    }

    static func fetchMetadata(client: Client, package: Package) throws -> EventLoopFuture<Metadata> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let url = try apiUri(for: package)
        let request = client
            .get(url, headers: getHeaders)
            .flatMapThrowing { response -> Metadata in
                guard response.status == .ok else { throw AppError.requestFailed(response.status) }
                return try response.content.decode(Metadata.self, using: decoder)
        }
        return request
    }

    static var getHeaders: HTTPHeaders {
        // Set User-Agent or we get a 403
        // https://developer.github.com/v3/#user-agent-required
        var headers = HTTPHeaders([("User-Agent", "SPI-Server")])
        if let token = Current.githubToken() {
            headers.add(name: "Authorization", value: "token \(token)")
        }
        return headers
    }

    static func apiUri(for package: Package) throws -> URI {
        let githubPrefix = "https://github.com/"
        let gitSuffix = ".git"
        guard package.url.hasPrefix(githubPrefix) else { throw AppError.invalidPackageUrl }
        var url = package.url.dropFirst(githubPrefix.count)
        if url.hasSuffix(gitSuffix) { url = url.dropLast(gitSuffix.count) }
        return URI(string: "https://api.github.com/repos/\(url)")
    }
}



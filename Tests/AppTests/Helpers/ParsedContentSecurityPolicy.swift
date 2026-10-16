// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwiftSoup
import Vapor


/// A `Content-Security-Policy` header value, split into its directives.
struct ParsedContentSecurityPolicy {
    let directives: [String: [String]]

    init(_ header: String) {
        let pairs = header.split(separator: ";").compactMap { directive -> (String, [String])? in
            let tokens = directive.split(separator: " ").map(String.init)
            return tokens.first.map { ($0, Array(tokens.dropFirst())) }
        }
        directives = Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    /// Each script in `html` that a browser enforcing this policy would not run: an external script as
    /// its URL, an inline one as the hash that would allow it followed by its source.
    func blockedScripts(in html: String) throws -> [String] {
        guard let sources = directives["script-src"] ?? directives["default-src"] else { return [] }
        // A hash or nonce in the list makes browsers ignore `'unsafe-inline'`.
        let allowsAnyInline = sources.contains("'unsafe-inline'")
            && !sources.contains { $0.hasPrefix("'sha") || $0.hasPrefix("'nonce-") }
        return try SwiftSoup.parse(html).select("script").array().compactMap { script in
            let src = try script.attr("src")
            guard src.isEmpty else { return Self.allows(src, sources) ? nil : src }
            let source = script.data()
            let hash = "'sha256-\(Data(SHA256.hash(data: Data(source.utf8))).base64EncodedString())'"
            let isAllowed = switch try script.attr("type").lowercased() {
                case "", "text/javascript", "module": allowsAnyInline || sources.contains(hash)
                default: true
            }
            return isAllowed ? nil : "\(hash) \(source)"
        }
    }

    private static func allows(_ src: String, _ sources: [String]) -> Bool {
        guard let url = URL(string: src), let scheme = url.scheme, let host = url.host else {
            return sources.contains("'self'")
        }
        return sources.contains("\(scheme)://\(host)")
    }
}

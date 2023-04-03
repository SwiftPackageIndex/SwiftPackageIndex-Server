//
//                Apache License, Version 2.0
//
//  Copyright 2017, Markus Wanke
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

/// # OhhAuth
/// ## Pure Swift implementation of the OAuth 1.0 protocol as an easy to use extension for the URLRequest type.
/// - Author: Markus Wanke
/// - Copyright: 2017

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Crypto

public class OhhAuth
{
    /// Tuple to represent signing credentials. (consumer as well as user credentials)
    public typealias Credentials = (key: String, secret: String)


    /// Function to calculate the OAuth protocol parameters and signature ready to be added
    /// as the HTTP header "Authorization" entry. A detailed explanation of the procedure
    /// can be found at: [RFC-5849 Section 3](https://tools.ietf.org/html/rfc5849#section-3)
    ///
    /// - Parameters:
    ///   - url: Request url (with all query parameters etc.)
    ///   - method: HTTP method
    ///   - parameter: url-form parameters
    ///   - consumerCredentials: consumer credentials
    ///   - userCredentials: user credentials (nil if this is a request without user association)
    ///
    /// - Returns: OAuth HTTP header entry for the Authorization field.
    public static func calculateSignature(url: URL, method: String, parameter: [String: String],
        consumerCredentials cc: Credentials, userCredentials uc: Credentials?) -> String
    {
        typealias Tup = (key: String, value: String)

        let tuplify: (String, String) -> Tup = {
            return (key: rfc3986encode($0), value: rfc3986encode($1))
        }
        let cmp: (Tup, Tup) -> Bool = {
            return $0.key < $1.key
        }
        let toPairString: (Tup) -> String = {
            return $0.key + "=" + $0.value
        }
        let toBrackyPairString: (Tup) -> String = {
            return $0.key + "=\"" + $0.value + "\""
        }

        /// [RFC-5849 Section 3.1](https://tools.ietf.org/html/rfc5849#section-3.1)
        var oAuthParameters = oAuthDefaultParameters(consumerKey: cc.key, userKey: uc?.key)

        /// [RFC-5849 Section 3.4.1.3.1](https://tools.ietf.org/html/rfc5849#section-3.4.1.3.1)
        let signString: String = [oAuthParameters, parameter, url.queryParameters()]
            .flatMap { $0.map(tuplify) }
            .sorted(by: cmp)
            .map(toPairString)
            .joined(separator: "&")


        /// [RFC-5849 Section 3.4.1](https://tools.ietf.org/html/rfc5849#section-3.4.1)
        let signatureBase: String = [method, url.oAuthBaseURL(), signString]
            .map(rfc3986encode)
            .joined(separator: "&")

        /// [RFC-5849 Section 3.4.2](https://tools.ietf.org/html/rfc5849#section-3.4.2)
        let signingKey: String = [cc.secret, uc?.secret ?? ""]
            .map(rfc3986encode)
            .joined(separator: "&")

        guard let signatureBaseData = signatureBase.data(using: .utf8),
            let signingKeyData = signingKey.data(using: .utf8) else {
            return ""
        }
        /// [RFC-5849 Section 3.4.2](https://tools.ietf.org/html/rfc5849#section-3.4.2)
        let binarySignature = HMAC<Insecure.SHA1>.authenticationCode(for: signatureBaseData,
                                                                     using: .init(data: signingKeyData))
        oAuthParameters["oauth_signature"] = Data(binarySignature).base64EncodedString()

        /// [RFC-5849 Section 3.5.1](https://tools.ietf.org/html/rfc5849#section-3.5.1)
        return "OAuth " + oAuthParameters
            .map(tuplify)
            .sorted(by: cmp)
            .map(toBrackyPairString)
            .joined(separator: ",")
    }



    /// Function to perform the right percentage encoding for url form parameters.
    ///
    /// - Parameter paras: url-form parameters
    /// - Parameter encoding: used string encoding (default: .utf8)
    /// - Returns: correctly percentage encoded url-form parameters
    static func httpBody(forFormParameters paras: [String: String], encoding: String.Encoding = .utf8) -> Data?
    {
        let trans: (String, String) -> String = { k, v in
            return rfc3986encode(k) + "=" + rfc3986encode(v)
        }

        return paras.map(trans).joined(separator: "&").data(using: encoding)
    }

    /// OAuth cites RFC-3986 for percentage encoding.
    /// Characters that don't need to be converted are: ALPHA, DIGIT, "-", ".", "_", "~"
    /// [RFC-5849 Section 3.6](https://tools.ietf.org/html/rfc5849#section-3.6)
    /// [RFC-3986 Section 2.3](https://tools.ietf.org/html/rfc3986#section-2.3)
    /// Predefined CharacterSets are not used to be 100% RFC conform and
    /// avoid possible unicode conversion problems.
    private static func rfc3986encode(_ str: String) -> String
    {
        struct Static {
            static let allowed = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._~"
            static let allowedSet = CharacterSet(charactersIn: allowed)
        }
        return str.addingPercentEncoding(withAllowedCharacters: Static.allowedSet) ?? str
    }

    private static func oAuthDefaultParameters(consumerKey: String, userKey: String?) -> [String: String]
    {
        /// [RFC-5849 Section 3.1](https://tools.ietf.org/html/rfc5849#section-3.1)
        var defaults: [String: String] = [
            "oauth_consumer_key":     consumerKey,
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_version":          "1.0",
            /// [RFC-5849 Section 3.3](https://tools.ietf.org/html/rfc5849#section-3.3)
            "oauth_timestamp":        String(Int(Date().timeIntervalSince1970)),
            "oauth_nonce":            UUID().uuidString,
        ]
        if let userKey = userKey {
            defaults["oauth_token"] = userKey
        }
        return defaults
    }
}


public extension URLRequest
{
    /// Easy to use method to sign a URLRequest which includes url-form parameters with OAuth.
    /// The request needs a valid URL with all query parameters etc. included.
    /// After calling this method the HTTP header fields: "Authorization", "Content-Type"
    /// and "Content-Length" should not be overwritten.
    ///
    /// - Parameters:
    ///   - method: HTTP Method
    ///   - paras: url-form parameters
    ///   - consumerCredentials: consumer credentials
    ///   - userCredentials: user credentials (nil if this is a request without user association)
    mutating func oAuthSign(method: String, urlFormParameters paras: [String: String],
        consumerCredentials cc: OhhAuth.Credentials, userCredentials uc: OhhAuth.Credentials? = nil)
    {
        self.httpMethod = method.uppercased()

        let body = OhhAuth.httpBody(forFormParameters: paras)

        self.httpBody = body
        self.addValue(String(body?.count ?? 0), forHTTPHeaderField: "Content-Length")
        self.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let sig = OhhAuth.calculateSignature(url: self.url!, method: self.httpMethod!,
                      parameter: paras, consumerCredentials: cc, userCredentials: uc)

        self.addValue(sig, forHTTPHeaderField: "Authorization")
    }

    /// Easy to use method to sign a URLRequest which includes plain body data with OAuth.
    /// The request needs a valid URL with all query parameters etc. included.
    /// After calling this method the HTTP header fields: "Authorization", "Content-Type"
    /// and "Content-Length" should not be overwritten.
    ///
    /// - Parameters:
    ///   - method: HTTP Method
    ///   - body: HTTP request body (default: nil)
    ///   - contentType: HTTP header "Content-Type" entry (default: nil)
    ///   - consumerCredentials: consumer credentials
    ///   - userCredentials: user credentials (nil if this is a request without user association)
    mutating func oAuthSign(method: String, body: Data? = nil, contentType: String? = nil,
        consumerCredentials cc: OhhAuth.Credentials, userCredentials uc: OhhAuth.Credentials? = nil)
    {
        self.httpMethod = method.uppercased()

        if let body = body {
            self.httpBody = body
            self.addValue(String(body.count), forHTTPHeaderField: "Content-Length")
        }

        if let ct = contentType {
            self.addValue(ct, forHTTPHeaderField: "Content-Type")
        }

        let sig = OhhAuth.calculateSignature(url: self.url!, method: self.httpMethod!,
                      parameter: [:], consumerCredentials: cc, userCredentials: uc)

        self.addValue(sig, forHTTPHeaderField: "Authorization")
    }
}

fileprivate extension URL
{
    /// Transforms: "www.x.com?color=red&age=29" to ["color": "red", "age": "29"]
    func queryParameters() -> [String: String]
    {
        var res: [String: String] = [:]
        for qi in URLComponents(url: self, resolvingAgainstBaseURL: true)?.queryItems ?? [] {
            res[qi.name] = qi.value ?? ""
        }
        return res
    }

    /// [RFC-5849 Section 3.4.1.2](https://tools.ietf.org/html/rfc5849#section-3.4.1.2)
    func oAuthBaseURL() -> String
    {
        let scheme = self.scheme?.lowercased() ?? ""
        let host = self.host?.lowercased() ?? ""

        var authority = ""
        if let user = self.user, let pw = self.password {
            authority = user + ":" + pw + "@"
        }
        else if let user = self.user {
            authority = user + "@"
        }

        var port = ""
        if let iport = self.port, iport != 80, scheme == "http" {
            port = ":\(iport)"
        }
        else if let iport = self.port, iport != 443, scheme == "https" {
            port = ":\(iport)"
        }

        return scheme + "://" + authority + host + port + self.path
    }
}

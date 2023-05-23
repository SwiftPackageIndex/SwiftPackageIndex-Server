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


extension String {
    var droppingGithubComPrefix: String {
        if lowercased().hasPrefix(Constants.githubComPrefix) {
            return String(dropFirst(Constants.githubComPrefix.count))
        }
        return self
    }

    var droppingGitExtension: String {
        if lowercased().hasSuffix(Constants.gitSuffix) {
            return String(dropLast(Constants.gitSuffix.count))
        }
        return self
    }

    func removingSuffix(_ suffix: String) -> String {
        if lowercased().hasSuffix(suffix.lowercased()) {
            return String(self.dropLast(suffix.count))
        }
        return self
    }

    var trimmed: String? {
        let trimmedString = trimmingCharacters(in: .whitespaces)
        if trimmedString.isEmpty { return nil }
        return trimmedString
    }

    func prefixIfNeeded(_ prefix: String) -> Self {
        hasPrefix(prefix) ? self : prefix + self
    }
}


extension String {
    // Keep in sync with https://github.com/SwiftPackageIndex/DocUploader/blob/main/Sources/DocUploadBundle/String%2Bext.swift
    // We should pull this out into a shared module perhaps but it's a lot of fiddling for just a single method.
    var pathEncoded: Self {
        replacingOccurrences(of: "/", with: "-")
    }
}


// MARK: - Pluralisation

extension String {
    func pluralized(for count: Int, plural: String? = nil) -> String {
        let plural = plural ?? self + "s"
        switch count {
            case 0:
                return plural
            case 1:
                return self
            default:
                return plural
        }
    }
}


extension String.StringInterpolation {

    mutating func appendInterpolation<T: CustomStringConvertible>(_ value: T?) {
        appendInterpolation(value, defaultValue: "nil")
    }

    mutating func appendInterpolation<T: CustomStringConvertible>(
        _ value: T?,
        defaultValue: @autoclosure () -> String) {
        appendInterpolation(value ?? defaultValue() as CustomStringConvertible)
    }

}


// MARK: - SHA256 checksum

import Crypto

extension String {
    var sha256Checksum: String {
        return SHA256.hash(data: Data(utf8)).hexString
    }
}

private extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexString: String {
        bytes.map { String(format: "%02X", $0) }
            .joined()
            .lowercased()
    }
}


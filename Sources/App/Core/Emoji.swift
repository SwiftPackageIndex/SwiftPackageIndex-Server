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

import Dependencies
import Vapor


fileprivate struct Emoji: Decodable {
    enum CodingKeys: String, CodingKey {
        case unicode = "emoji"
        case names = "aliases"
    }

    let unicode: String
    let names: [String]
}


struct EmojiStorage {
    nonisolated(unsafe) static var current = EmojiStorage()
    var lookup: [String: String]
    var regularExpression: NSRegularExpression?

    init() {
        @Dependency(\.fileManager) var fileManager
        let pathToEmojiFile = fileManager.workingDirectory().appending("Resources/emoji.json")

        lookup = [:]
        regularExpression = nil

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: pathToEmojiFile))
            let emojis = try JSONDecoder().decode([Emoji].self, from: data)

            lookup = emojis.reduce(into: [String: String]()) { lookup, emoji in
                emoji.names.forEach {
                    lookup[":\($0):"] = emoji.unicode
                }
            }

            let escapedKeys = lookup.keys.map(NSRegularExpression.escapedPattern(for:))
            let pattern = "(" + escapedKeys.joined(separator: "|") + ")"
            regularExpression = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            print("🚨 Failed to decode emoji list: \(error)")
        }
    }

    func replace(inString string: String) -> String {
        guard let regEx = regularExpression else {
            return string
        }

        let nsRange = NSRange(location: 0, length: string.count)
        let results = regEx.matches(in: string, options: [], range: nsRange)

        var mutableString = string
        results.reversed().forEach { result in
            let shorthand = (string as NSString).substring(with: result.range)

            if let range = Range(result.range, in: mutableString), let unicode = lookup[shorthand] {
                mutableString = mutableString.replacingCharacters(in: range, with: unicode)
            }
        }

        return mutableString
    }
}


extension String {
    func replaceShorthandEmojis() -> String {
        return EmojiStorage.current.replace(inString: self)
    }
}

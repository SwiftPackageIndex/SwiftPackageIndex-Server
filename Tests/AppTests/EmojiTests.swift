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

@testable import App

import Testing


extension AllTests.EmojiTests {

    @Test func emojiReplacement() throws {
        let cases: [(shorthand: String, result: String)] = [
            (":smile:", "😄"),
            (":grinning:", "😀"),
            (":gb:", "🇬🇧"),
            (":+1:", "👍"),
            (":shaking_face:", "🫨"),
            (":invalid:", ":invalid:")
        ]

        cases.forEach { test in
            #expect(test.shorthand.replaceShorthandEmojis() == test.result)
        }
    }

    @Test func emojiLoading() throws {
        let emojis = EmojiStorage.current.lookup
        #expect(emojis.count == 1913)
        #expect(emojis[":grinning:"] == "😀")
    }

}

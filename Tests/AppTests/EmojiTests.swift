// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import XCTest

class EmojiTests: XCTestCase {

    func test_emojiReplacement() throws {
        let cases: [(shorthand: String, result: String)] = [
            (":smile:", "😄"),
            (":grinning:", "😀"),
            (":gb:", "🇬🇧"),
            (":+1:", "👍"),
            (":invalid:", ":invalid:")
        ]
        
        cases.forEach { test in
            XCTAssertEqual(test.shorthand.replaceShorthandEmojis(), test.result)
        }
    }
    
    func test_emojiLoading() throws {
        let emojis = EmojiStorage.current.lookup
        XCTAssertEqual(emojis.count, 1848)
        XCTAssertEqual(emojis[":grinning:"], "😀")
    }
    
}

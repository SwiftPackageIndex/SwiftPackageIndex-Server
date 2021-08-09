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
    
    func test_emojiReplacementPerformance() throws {
        let sentence = """
        Lorem commodo hac :smile: accumsan massa odio :joy: nunc, phasellus vitae sed ante
        orci tortor integer, fringilla at sem ex :star_struck: vivamus :grin:. Vel purus metus urna
        non quis efficitur :: :smirk:, dapibus suspendisse sem :thinking: dolor varius ultrices
        sodales, pellentesque odio platea at :eyes: tincidunt netus :invalid:. Ultrices vestibulum
        tincidunt :raised_eyebrow : in ipsum efficitur class rhoncus arcu, porta justo aliquet augue.
        """
        
        let expected = """
        Lorem commodo hac 😄 accumsan massa odio 😂 nunc, phasellus vitae sed ante
        orci tortor integer, fringilla at sem ex 🤩 vivamus 😁. Vel purus metus urna
        non quis efficitur :: 😏, dapibus suspendisse sem 🤔 dolor varius ultrices
        sodales, pellentesque odio platea at 👀 tincidunt netus :invalid:. Ultrices vestibulum
        tincidunt :raised_eyebrow : in ipsum efficitur class rhoncus arcu, porta justo aliquet augue.
        """
        
        // Cache the emojis as to not have an impact on the future performance.
        _ = EmojiStorage.current.lookup
        
        measure {
            XCTAssertEqual(sentence.replaceShorthandEmojis(), expected)
        }
    }

}

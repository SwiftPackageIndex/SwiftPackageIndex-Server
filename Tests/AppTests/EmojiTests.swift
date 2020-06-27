@testable import App

import XCTest

class EmojiTests: XCTestCase {

    func test_emojiReplacement() throws {
        let cases: [(shorthand: String, result: String)] = [
            (":smile:", "😀"),
            (":grinning:", "😀"),
            (":gb:", "🇬🇧"),
            (":invalid:", ":invalid:")
        ]
        
        cases.forEach { test in
            XCTAssertEqual(test.shorthand.replaceShorthandEmojis(), test.result)
        }
    }
    
    func test_emojiLoading() throws {
        let emojis = Emoji.fetchAll()
        XCTAssertEqual(emojis.count, 1805)
        XCTAssertEqual(emojis[0].unicode, "😀")
        XCTAssertEqual(emojis[0].names, ["grinning", "smile", "happy"])
    }

}

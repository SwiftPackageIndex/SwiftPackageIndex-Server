import Foundation
import Vapor

struct Emoji: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case emoji
        case aliases
        case tags
    }
    
    let unicode: String
    let names: [String]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unicode = try container.decode(String.self, forKey: .emoji)
        
        let aliases = try container.decode([String].self, forKey: .aliases)
        let tags = try container.decode([String].self, forKey: .tags)
        names = aliases + tags
    }
    
}

extension Emoji {
    
    static func fetchAll() -> [Emoji] {
        let pathToEmojiFile = Current.fileManager.workingDirectory()
            .appending("Resources/emoji.json")
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: pathToEmojiFile))
            return try JSONDecoder().decode([Emoji].self, from: data)
        } catch {
            print("🚨 Failed to decode emoji list: \(error)")
            return []
        }
    }
    
}

extension String {
    
    func replaceShorthandEmojis() -> String {
        var builder = self
        Emoji.fetchAll().forEach { emoji in
            emoji.names.forEach { emojiShortcode in
                builder = builder.replacingOccurrences(of: ":\(emojiShortcode):", with: emoji.unicode)
            }
        }
        return builder
    }
    
}

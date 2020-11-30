@testable import App
import Foundation


extension Release {
    static func mock(descripton: String, tagName: String) -> Self {
        .init(createdAt: Date(),
              description: descripton,
              isDraft: false,
              publishedAt: Date(),
              tagName: tagName,
              url: "")
    }
}

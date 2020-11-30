@testable import App
import Foundation


extension Release {
    static func mock(descripton: String,
                     isDraft: Bool = false,
                     publishedAt: Date = Current.date(),
                     tagName: String,
                     url: String = "") -> Self {
        .init(createdAt: Date(),
              description: descripton,
              isDraft: isDraft,
              publishedAt: publishedAt,
              tagName: tagName,
              url: url)
    }
}

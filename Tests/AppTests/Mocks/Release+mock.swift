@testable import App
import Foundation


extension Release {
    static func mock(descripton: String,
                     isDraft: Bool = false,
                     publishedAt: Int = 0,
                     tagName: String,
                     url: String = "") -> Self {
        .init(description: descripton,
              isDraft: isDraft,
              publishedAt: Date(timeIntervalSince1970: TimeInterval(publishedAt)),
              tagName: tagName,
              url: url)
    }
}

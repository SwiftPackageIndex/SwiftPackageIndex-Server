@testable import App
import Foundation


extension Release {
    static func mock(descripton: String?,
                     isDraft: Bool = false,
                     publishedAt: Int? = nil,
                     tagName: String,
                     url: String = "") -> Self {
        .init(description: descripton,
              isDraft: isDraft,
              publishedAt: publishedAt
                .map(TimeInterval.init)
                .map(Date.init(timeIntervalSince1970:)),
              tagName: tagName,
              url: url)
    }
}

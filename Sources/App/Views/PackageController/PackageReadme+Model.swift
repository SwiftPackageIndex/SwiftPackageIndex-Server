import Foundation
import Vapor
import SwiftSoup

extension PackageReadme {
    
    struct Model: Equatable {
        private var readmeElement: Element?

        internal init(readme: String?) {
            self.readmeElement = processReadme(readme)
        }

        var readme: String? {
            guard let readmeElement = readmeElement else { return nil }

            do {
                return try readmeElement.html()
            } catch {
                return nil
            }
        }

        func processReadme(_ rawReadme: String?) -> Element? {
            guard let rawReadme = rawReadme else { return nil }
            guard let readmeElement = extractReadmeElement(rawReadme) else { return nil }
            return readmeElement
        }

        func extractReadmeElement(_ rawReadme: String) -> Element? {
            do {
                let htmlDocument = try SwiftSoup.parse(rawReadme)
                let readmeElements = try htmlDocument.select("#readme article")
                guard let articleElement = readmeElements.first()
                else { return nil } // There is no README if this element doesn't exist.
                return articleElement
            } catch {
                return nil
            }
        }
    }
}

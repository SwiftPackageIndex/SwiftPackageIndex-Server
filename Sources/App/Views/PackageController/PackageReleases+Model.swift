import Foundation
import Vapor
import SwiftSoup

extension PackageReleases {
    
    struct Model: Equatable {
        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMMM yyyy"
            
            return formatter
        }()
        
        struct Release: Equatable {
            let title: String
            let date: String?
            let html: String?
        }
        
        let releases: [Release]
        
        internal init?(package: Package) {
            guard let releases = package.repository?.releases,
                  releases.isEmpty == false
            else {
                return nil
            }
            
            self.releases = releases.map { release in
                Release(
                    title: release.tagName,
                    date: Self.formatDate(release.publishedAt),
                    html: Self.updateDescription(release.descriptionHTML, replacingTitle: release.tagName)
                )
            }
        }
        
        static func formatDate(_ date: Date?, currentDate: Date = Current.date()) -> String? {
            #warning("TODO: add test covering function")
            
            guard let date = date else { return nil }
            return "Released \(date: date, relativeTo: currentDate) on \(Self.dateFormatter.string(from: date))"
        }
        
        static func updateDescription(_ description: String?, replacingTitle title: String) -> String? {
            #warning("TODO: add test covering function")
            
            guard let description = description?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !description.isEmpty
            else { return nil }
            
            do {
                let htmlDocument = try SwiftSoup.parse(description)
                let headerElements = try htmlDocument.select("h1, h2, h3, h4, h5, h6")
                
                guard let titleHeader = headerElements.first()
                else { return description }
                
                if try titleHeader.text().contains(title) {
                    try titleHeader.remove()
                }
                
                return try htmlDocument.html()
            } catch {
                return description
            }
        }
    }
}

import Foundation
import Vapor

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
                    date: release.publishedAt.map {
                        "Released \(date: $0, relativeTo: Current.date()) on \(Self.dateFormatter.string(from: $0))"
                    },
                    html: release.descriptionHTML
                )
            }
        }

    }
}

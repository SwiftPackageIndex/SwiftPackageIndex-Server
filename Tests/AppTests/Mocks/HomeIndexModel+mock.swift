@testable import App


extension HomeIndex.Model {
    static var mock: HomeIndex.Model {
        .init(
            recentPackages: [
                .init(date: "2 hours ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "2 hours ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "2 hours ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "2 hours ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "2 hours ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "2 hours ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
            ],
            recentReleases: [
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
        ])
    }
}

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
                .init(date: "20 minutes ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "20 minutes ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "20 minutes ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "20 minutes ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "20 minutes ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: "20 minutes ago",
                      link: .init(label: "Package", url: "https://example.com/package")),
        ])
    }
}

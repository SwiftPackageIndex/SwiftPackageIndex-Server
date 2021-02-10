@testable import App


extension Git {
    static let mock: Self = .init(
        commitCount: { _ in fatalError("not initialized") },
        firstCommitDate: { _ in fatalError("not initialized") },
        lastCommitDate: { _ in fatalError("not initialized") },
        getTags: { _ in fatalError("not initialized") },
        showDate: { _,_ in fatalError("not initialized") },
        revisionInfo: { _,_ in fatalError("not initialized") }
    )
}

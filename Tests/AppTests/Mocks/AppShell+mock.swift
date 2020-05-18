@testable import App


extension App.Shell {
    static let mock: Self = .init(run: { cmd, path in
        print("ℹ️ MOCK: imagine we're running \(cmd) at path: \(path)")
        return ""
    })
}

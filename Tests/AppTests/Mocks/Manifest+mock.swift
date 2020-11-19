@testable import App


extension Manifest {
    static var mock: Self {
        .init(name: "MockManifest", products: [.mock])
    }
}

extension Manifest.Product {
    static var mock: Self {
        .init(name: "MockProduct", type: .library)
    }
}

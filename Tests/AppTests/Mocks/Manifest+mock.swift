@testable import App


extension Manifest {
    static var mock: Self {
        .init(name: "MockManifest", products: [.mock], targets: [])
    }
}

extension Manifest.Product {
    static var mock: Self {
        .init(name: "MockProduct", type: .library(.automatic))
    }
}

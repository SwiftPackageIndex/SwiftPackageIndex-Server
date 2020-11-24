import Logging


extension Logger {
    init(component: String) {
        self.init(label: component)
        self[metadataKey: "component"] = .string(component)
    }
}

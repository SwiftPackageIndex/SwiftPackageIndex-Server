import Logging


extension Logger {
    init(component: String) {
        self.init(label: component)
        self.component = component
    }

    var component: String? {
        get { self[metadataKey: "component"].map { "\($0)" } }
        set {
            guard let newValue = newValue else { return }
            self[metadataKey: "component"] = .string(newValue)
        }
    }
}

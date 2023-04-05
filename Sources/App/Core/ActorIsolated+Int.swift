extension ActorIsolated where Value == Int {
    public func increment(by delta: Int = 1) {
        self.value += delta
    }

    public func decrement(by delta: Int = 1) {
        self.value -= delta
    }
}

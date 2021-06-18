extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        clamped(to: limits.lowerBound...)
            .clamped(to: ...limits.upperBound)
    }

    func clamped(to limit: PartialRangeFrom<Self>) -> Self {
        max(self, limit.lowerBound)
    }

    func clamped(to limit: PartialRangeThrough<Self>) -> Self {
        min(self, limit.upperBound)
    }
}

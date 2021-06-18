extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }

    func clamped(to limit: PartialRangeFrom<Self>) -> Self {
        return max(self, limit.lowerBound)
    }

    func clamped(to limit: PartialRangeThrough<Self>) -> Self {
        return min(self, limit.upperBound)
    }
}

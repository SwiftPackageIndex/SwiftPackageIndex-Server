enum Score {
    struct Input {
        var supportsLatestSwiftVersion: Bool
        var releaseCount: Int
        var likeCount: Int
    }

    static func compute(_ candidate: Input) -> Int {
        var score = 0

        // Swift major version support
        if candidate.supportsLatestSwiftVersion { score += 10 }

        // Number of releases
        switch candidate.releaseCount {
            case  ..<5 :   break
            case 5..<20:   score += 10
            default    :   score += 20
        }

        // Stars count
        switch candidate.likeCount {
            case      ..<25    :  break
            case    25..<100   :  score += 10
            case   100..<500   :  score += 20
            case   500..<5_000 :  score += 30
            case 5_000..<10_000:  score += 40
            default:              score += 50
        }

        return score
    }
}


extension Package {
    func computeScore() -> Int {
        guard
        let defaultVersion = defaultVersion(),
            let versions = $versions.value,
            let r = repository,
            let starsCount = r.stars
            else { return 0 }
        let releases = versions.filter { $0.reference?.isTag ?? false }
        return Score.compute(
            .init(supportsLatestSwiftVersion: defaultVersion.supportsMajorSwiftVersion(Constants.latestMajorSwiftVersion),
                  releaseCount: releases.count,
                  likeCount: starsCount)
        )
    }
}

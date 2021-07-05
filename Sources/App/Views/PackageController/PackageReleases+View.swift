import Vapor
import Plot

enum PackageReleases {
    
    class View: TurboFrame {
        
        let model: Model?

        init(model: Model?) {
            self.model = model
            super.init()
        }

        override func frameIdentifier() -> String {
            "releases"
        }

        override func frameContent() -> Node<HTML.BodyContext> {
            guard let releases = model?.releases
            else { return .empty }
            
            return .group(
                .forEach(releases.enumerated()) { (index, release) in
                    group(forRelease: release, isLast: index == releases.count - 1)
                }
            )
        }
        
        func group(forRelease release: Model.Release, isLast: Bool) -> Node<HTML.BodyContext> {
            .group(
                .h2(.text(release.title)),
                .unwrap(release.date) { .small(.text($0)) },
                .unwrap(release.html) { .raw($0) },
                .if(isLast == false, .hr())
            )
        }
    }
    
}

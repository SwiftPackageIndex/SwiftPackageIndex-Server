import Vapor
import Plot

enum PackageReadme {
    
    class View: TurboFrame {
        
        let model: Model

        init(model: Model) {
            self.model = model
            super.init()
        }

        override func frameIdentifier() -> String {
            "readme"
        }

        override func frameContent() -> Node<HTML.BodyContext> {
            guard let readme = model.readme
            else { return .empty }

            return .group(
                .hr(),
                .spiReadme(
                    .raw(readme)
                )
            )
        }
    }
    
}

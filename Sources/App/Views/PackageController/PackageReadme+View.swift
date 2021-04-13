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
            .text("Hello, Dynamic.")
        }
    }
    
}

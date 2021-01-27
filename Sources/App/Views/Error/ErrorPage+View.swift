import Plot
import Vapor

enum ErrorPage {
    
    final class View: PublicPage {
        let model: Model
        
        
        init(path: String, error: AbortError) {
            self.model = Model(error)
            super.init(path: path)
        }
        
        
        override func content() -> Node<HTML.BodyContext> {
            .section(
                .class("error_message"),
                .h4("Something went wrong. Sorry!"), // Note: This copy intentionally matches the copy in `search_core.js`.
                .p(.text(model.errorMessage)),
                .unwrap(model.errorInstructions) { .p(.text($0)) }
            )
        }
        
    }
    
}

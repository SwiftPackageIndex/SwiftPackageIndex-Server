import Plot
import Foundation

enum SuccessfulChange {

    struct Model {
        var successMessage: String = ""
    }
    
    class View: PublicPage {
        
        let model: Model
        
        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            "Success"
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .div(
                .text(self.model.successMessage),
                .loginButton()
            )
        }
    }
}

// TODO: move to plot extensions
extension Node where Context: HTML.BodyContext {
    static func loginButton() -> Self {
        .form(
            .action(SiteURL.login.relativeURL()),
            .button(
                .text("Login"),
                .type(.submit)
            )
        )
    }
}

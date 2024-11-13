import Plot
import Foundation

enum Signup {

    struct Model {
        var errorMessage: String = ""
    }
    
    class View: PublicPage {
        
        let model: Model
        
        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            "Sign up"
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .div(
                .class("manage-page"),
                .h2("Signup"),
                .signupForm(),
                .text(model.errorMessage)
            )
        }
    }
}

// TODO: move to plot extensions
extension Node where Context: HTML.BodyContext {
    static func signupForm(email: String = "", password: String = "") -> Self {
        .form(
            .action(SiteURL.signup.relativeURL()),
            .method(.post),
            .data(named: "turbo", value: "false"),
            .emailField(email: email),
            .passwordField(password: password),
            .button(
                .text("Sign up"),
                .type(.submit)
            )
        )
    }
}

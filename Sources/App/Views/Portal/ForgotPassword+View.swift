import Plot
import Foundation

enum ForgotPassword {
    
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
            "Forgot Password"
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .div(
                .class("portal-page"),
                .h2("An email will be sent with a reset code"),
                .forgotPasswordForm(),
                .text(model.errorMessage)
            )
        }
    }
}

extension Node where Context: HTML.BodyContext {
    static func forgotPasswordForm(email: String = "") -> Self {
        .form(
            .action(SiteURL.forgotPassword.relativeURL()),
            .method(.post),
            .data(named: "turbo", value: "false"),
            .emailField(email: email)   ,
            .button(
                .type(.submit)
            )
        )
    }
}

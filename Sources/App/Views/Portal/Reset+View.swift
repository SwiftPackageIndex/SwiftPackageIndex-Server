import Plot
import Foundation

enum Reset {
    
    struct Model {
        var email: String = ""
        var errorMessage: String = ""
    }
    
    class View: PublicPage {
        
        let model: Model
        
        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            "Reset Password"
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Reset Password"),
                .resetPasswordForm(),
                .text(model.errorMessage)
            )
        }
    }
}

// TODO: move to plot extensions
extension Node where Context: HTML.BodyContext {
    static func resetPasswordForm(email: String = "", password: String = "", code: String = "") -> Self {
        .form(
            .action(SiteURL.resetPassword.relativeURL()),
            .method(.post),
            .data(named: "turbo", value: "false"),
            .codeField(code: code),
            .emailField(email: email)   ,
            .passwordField(password: password, passwordFieldText: "Enter new password"),
            .button(
                .text("Send reset code"),
                .type(.submit)
            )
        )
    }
}


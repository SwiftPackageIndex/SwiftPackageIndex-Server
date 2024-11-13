import Plot
import Foundation

enum ForgotPassword {
    
    class View: PublicPage {
        
        override func pageTitle() -> String? {
            "Forgot Password"
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .div(
                .class("manage-page"),
                .h2("An email will be sent with a reset code"),
                .forgotPasswordForm()
            )
        }
    }
}

// TODO: move to plot extensions
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

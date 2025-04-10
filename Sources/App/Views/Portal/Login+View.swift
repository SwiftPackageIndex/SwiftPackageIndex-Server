import Plot
import Foundation

enum Login {
    
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
            "Log in"
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Login to Swift Package Index"),
                .loginForm(),
                .if(model.errorMessage.isEmpty == false,
                    .p(
                        .text(model.errorMessage)
                    )
                ),
                .signupButton("Create an account"),
                .forgotPassword("Reset your password")
            )
        }
    }
}

extension Node where Context: HTML.BodyContext {
    static func loginForm(email: String = "", password: String = "") -> Self {
        .form(
            .action(SiteURL.login.relativeURL()),
            .method(.post),
            .data(named: "turbo", value: "false"),
            .emailField(email: email)   ,
            .passwordField(password: password),
            .button(
                .text("Login"),
                .type(.submit)
            )
        )
    }

    static func signupButton(_ text: String) -> Self {
        .form(
            .class("signup"),
            .action(SiteURL.signup.relativeURL()),
            .button(
                .text(text),
                .type(.submit)
            )
        )
    }
    
    static func forgotPassword(_ text: String) -> Self {
        .form(
            .class("forgot"),
            .action(SiteURL.forgotPassword.relativeURL()),
            .button(
                .text(text),
                .type(.submit)
            )
        )
    }
}


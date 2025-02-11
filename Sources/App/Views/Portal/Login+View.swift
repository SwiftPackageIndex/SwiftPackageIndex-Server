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
                .h2("Login"),
                .loginForm(),
                .text(model.errorMessage),
                .h2("Dont have an account?"),
                .signupButton(),
                .h2("Forgot password?"),
                .forgotPassword()
            )
        }
    }
}

// TODO: move to plot extensions
extension Node where Context: HTML.BodyContext {
    static func loginForm(email: String = "", password: String = "") -> Self {
        .div(
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
        )
    }
    
    static func signupButton() -> Self {
        .form(
            .action(SiteURL.signup.relativeURL()),
            .button(
                .text("Create an account"),
                .type(.submit)
            )
        )
    }
    
    static func forgotPassword() -> Self {
        .form(
            .action(SiteURL.forgotPassword.relativeURL()),
            .button(
                .text("Reset password"),
                .type(.submit)
            )
        )
    }
}

extension Node where Context == HTML.FormContext {
    static func emailField(email: String = "") -> Self {
        .input(
            .class("manage-form-inputs"),
            .id("email"),
            .name("email"),
            .type(.email),
            .placeholder("Enter email"),
            .spellcheck(false),
            .autocomplete(false),
            .value(email)
        )
    }
    
    static func passwordField(password: String = "", passwordFieldText: String = "Enter password") -> Self {
        .input(
            .class("manage-form-inputs"),
            .id("password"),
            .name("password"),
            .type(.password),
            .placeholder(passwordFieldText),
            .spellcheck(false),
            .autocomplete(false),
            .value(password)
        )
    }
}


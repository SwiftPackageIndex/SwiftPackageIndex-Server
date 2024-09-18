//
//  PortalView.swift
//
//

import Plot
import Foundation

enum Portal {
    
    class View: PublicPage {
        
       // let model: Model
        
//        init(path: String, model: Model) {
//            self.model = model
//            super.init(path: path)
//        }
        
        override func pageTitle() -> String? {
            "Portal"
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Login"),
                .loginForm(),
                .h2("Dont have an account?"),
                .signupButton()
            )
        }
    }
}

// move to other file later
extension Portal {
    struct Model {
        var email: String
        var password: String
    }
}

// move to plot extensions later
extension Node where Context: HTML.BodyContext {
    static func loginForm(email: String = "", password: String = "") -> Self {
        .form(
            .action(SiteURL.portal.relativeURL()),
            .loginField(email: email),
            .passwordField(password: password),
            .button(
                .type(.submit)
            )
        )
    }
    
    static func signupButton() -> Self {
        .form(
            .action(SiteURL.signup.relativeURL()),
            .button(
                .type(.submit)
            )
        )
    }
}

extension Node where Context == HTML.FormContext {
    static func loginField(email: String = "") -> Self {
        .input(
            .id("email"),
            .name("email"),
            .type(.email),
            .placeholder("Enter email"),
            .spellcheck(false),
            .autocomplete(false),
            .value(email)
        )
    }
    
    static func passwordField(password: String = "") -> Self {
        .input(
            .id("password"),
            .name("password"),
            .type(.password),
            .placeholder("Enter password"),
            .spellcheck(false),
            .autocomplete(false),
            .value(password)
        )
    }
}


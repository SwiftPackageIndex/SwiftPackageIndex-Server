import Plot
import Foundation

enum Verify {

    struct Model {
        var email: String
        var errorMessage: String = ""
    }

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Verify"
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .class("portal-form-container"),
                .h2("Please enter the confirmation code sent to your email"),
                .verifyForm(email: model.email),
                .text(model.errorMessage)
            )
        }
    }
}

extension Node where Context: HTML.BodyContext {
    static func verifyForm(email: String = "", code: String = "") -> Self {
        .form(
            .action(SiteURL.verify.relativeURL()),
            .method(.post),
            .input(
                .id("email"),
                .name("email"),
                .type(.hidden),
                .value(email)
            ),
            .confirmationCodeField(code: code),
            .data(named: "turbo", value: "false"),
            .button(
                .text("Confirm sign up"),
                .type(.submit)
            )
        )
    }
}

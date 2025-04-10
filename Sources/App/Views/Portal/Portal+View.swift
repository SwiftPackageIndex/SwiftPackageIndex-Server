import Plot
import Foundation

enum PortalPage {

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
            "Portal"
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .class("portal-form-container"),
                .h2("Portal"),
                .logoutButton(),
                .deleteButton(),
                .text(model.errorMessage)
            )
        }
    }
}

extension Node where Context: HTML.BodyContext {
    static func logoutButton() -> Self {
        .form(
            .class("portal-form-inputs"),
            .action(SiteURL.logout.relativeURL()),
            .method(.post),
            .data(named: "turbo", value: "false"),
            .button(
                .type(.submit),
                .text("logout")
            )
        )
    }

    static func deleteButton() -> Self {
        .form(
            .class("portal-form-inputs"),
            .action(SiteURL.deleteAccount.relativeURL()),
            .method(.post),
            .data(named: "turbo", value: "false"),
            .button(
                .type(.submit),
                .text("delete account")
            )
        )
    }
}

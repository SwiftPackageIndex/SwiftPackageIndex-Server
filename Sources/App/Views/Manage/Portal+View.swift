import Plot
import Foundation

enum Portal {
    
    class View: PublicPage {
        
        override func pageTitle() -> String? {
            "Portal"
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Portal"),
                .logoutButton(),
                .deleteButton()
            )
        }
    }
}

// TODO: move to plot extensions
extension Node where Context: HTML.BodyContext {
    static func logoutButton() -> Self {
        .form(
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

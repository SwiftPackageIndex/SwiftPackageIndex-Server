import Foundation
import Vapor
import Plot

class TurboFrame {

    /// The frame's full HTML content.
    /// - Returns: A <turbo-frame> element that will be rendered by Turbo.
    final func document() -> Node<HTML.BodyContext> {
        .turboFrame(id: frameIdentifier(), frameContent())
    }

    /// The identifier targeting which turbo frame should be replaced.
    /// - Returns: A string containing the identifier.
    func frameIdentifier() -> String {
        ""
    }

    /// The page content.
    /// - Returns: The node(s) that make up the frame's content.
    func frameContent() -> Node<HTML.BodyContext> {
        .empty
    }

}

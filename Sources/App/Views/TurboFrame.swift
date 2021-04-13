import Foundation
import Vapor
import Plot

class TurboFrame {

    /// The frame's full HTML content.
    /// - Returns: A <turbo-frame> element that will be rendered by Turbo.
    final func document() -> Node<HTML.BodyContext> {
        .turboFrame(
            frameContent()
        )
    }
    
    /// The page content.
    /// - Returns: The node(s) that make up the frame's content.
    func frameContent() -> Node<HTML.BodyContext> {
        .empty
    }

}

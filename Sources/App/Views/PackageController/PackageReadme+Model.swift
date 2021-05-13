import Foundation
import Plot
import Vapor

// This class previously had more than one property. We *could* make it a primitive string
// again at this point, but it has a bit more context this way, and I don't think we're done
// with readme files yet, so it may still be helpful.

extension PackageReadme {
    
    struct Model: Equatable {
        var readme: String?

        internal init(readme: String?) {
            self.readme = readme
        }
    }

}

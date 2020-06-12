import Vapor

extension ErrorPage {

    struct Model {
        let error: AbortError

        init(_ error: AbortError) {
            self.error = error
        }

        var errorMessage: String {
            get {
                var message = "\(error.status.code) - \(error.status.reasonPhrase)"
                if error.reason != error.status.reasonPhrase {
                    message += " - \(error.reason)"
                }
                return message
            }
        }

        var errorInstructions: String {
            get {
                switch error.status.code {
                    case 404:
                        return """
                        If you were expecting to see a page here, the site might be in the process of re-indexing this package.
                        Please try again in an hour or two.
                        """
                    default:
                        return ""
                }
            }
        }
    }
    
}

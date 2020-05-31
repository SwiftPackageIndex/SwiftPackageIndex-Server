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
    }
    
}

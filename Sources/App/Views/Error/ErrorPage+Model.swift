import Vapor

extension ErrorPage {

    struct Model {
        let status: HTTPStatus
        let error: AbortError?

        init(status: HTTPStatus, error: AbortError?) {
            self.status = status
            self.error = error
        }

        var errorMessage: String {
            get {
                var message = "\(status.code) - \(status.reasonPhrase)"
                if let error = error {
                    message += " - \(error.reason)"
                }
                return message

            }
        }
    }
    
}

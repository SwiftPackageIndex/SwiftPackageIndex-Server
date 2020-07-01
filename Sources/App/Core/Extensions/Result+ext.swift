
extension Result {
    func getError() -> Error? {
        switch self {
            case .success:
                return nil
            case .failure(let error):
                return error
        }
    }
}

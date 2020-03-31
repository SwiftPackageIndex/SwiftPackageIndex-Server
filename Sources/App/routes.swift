import Vapor

public func routes(_ router: Router) throws {
  router.get { _ in
    return "Hello, world!"
  }
}

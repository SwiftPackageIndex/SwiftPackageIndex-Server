import Vapor

public func routes(_ router: Router) throws {
  router.get { req in
    return "Hello, world!"
  }
}

import Vapor

struct RollbarCreateItem: Content {
  init(accessToken: String, environment: String, level: RollbarItemLevel, body: String) {
    self.accessToken = accessToken
    let body = RollbarCreateItemData.RollbarCreateItemDataBody(message: body)
    self.data = RollbarCreateItemData(environment: environment, body: body, level: level)
  }

  let accessToken: String
  let data: RollbarCreateItemData

  enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
      case data = "data"
  }

  struct RollbarCreateItemData: Content {
    let environment: String
    let body: RollbarCreateItemDataBody
    let level: RollbarItemLevel
    let language = "swift"
    let framework = "vapor"
    let uuid = UUID().uuidString

    struct RollbarCreateItemDataBody: Content {
      init(message: String) {
        self.message = .init(body: message)
      }

      let message: RollbarCreateItemDataBodyMessage

      struct RollbarCreateItemDataBodyMessage: Content {
        let body: String
      }
    }
  }
}

enum RollbarItemLevel: String, Codable {
  case critical = "critical"
  case error = "error"
  case warning = "warning"
  case info = "info"
  case debug = "debug"
}

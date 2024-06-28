// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Plot
import Vapor

protocol Renderable {
    func render() -> String
}

extension Renderable {
    public func encodeResponse(for request: Request) async throws -> Response {
        encodeResponse(status: .ok)
    }

    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        request.eventLoop.future(encodeResponse(status: .ok))
    }

    public func encodeResponse(status: HTTPResponseStatus) -> Response {
        let res = Response(status: status, body: .init(string: self.render()))
        res.headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
        return res
    }
}

extension Plot.HTML: Renderable, Vapor.ResponseEncodable, Vapor.AsyncResponseEncodable  {
}

extension Plot.Node: Renderable, Vapor.ResponseEncodable, Vapor.AsyncResponseEncodable {
}

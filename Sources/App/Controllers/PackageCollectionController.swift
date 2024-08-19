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

import Vapor


enum PackageCollectionController {
    @Sendable
    static func generate(req: Request) throws -> EventLoopFuture<SignedCollection> {
        AppMetrics.packageCollectionGetTotal?.inc()

        guard let owner = req.parameters.get("owner") else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return SignedCollection.generate(
            db: req.db,
            filterBy: .author(owner),
            authorName: "\(owner) via the Swift Package Index"
        ).flatMapError {
            if case PackageCollection.Error.noResults = $0 {
                return req.eventLoop.makeFailedFuture(Abort(.notFound))
            }
            return req.eventLoop.makeFailedFuture($0)
        }
    }
}

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

import SQLKit
import Vapor


enum Variant: String, LosslessStringConvertible {
    var description: String {
        rawValue
    }

    case all
    case active
    case docs

    init(_ string: String) {
        self = Variant(rawValue: string) ?? .active
    }
}


struct CreateRestfileCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "variant")
        var variant: Variant
    }

    var help: String { "Create restfile for automated testing" }

    func run(using context: CommandContext, signature: Signature) async throws {
        guard let db = context.application.db as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        try await createRestfile(on: db, variant: signature.variant)
    }
}


func createRestfile(on database: SQLDatabase, variant: Variant) async throws {
    let mode: String
    let query: SQLQueryString
    switch variant {
        case .active:
            mode = "random"
            query = """
                (
                select '/' || repository_owner || '/' || repository_name as url
                  from recent_packages
                union
                select '/' || repository_owner || '/' || repository_name as url
                  from recent_releases
                union
                select '/' || r.owner || '/' || r.name as url
                  from packages p
                  join repositories r on r.package_id = p.id
                  where score > 50
                )
                order by url
                """
        case .all:
            mode = "random"
            query = """
                select '/' || owner || '/' || name as url
                  from repositories
                  order by url
                """
        case .docs:
            mode = "sequential"
            query = """
                select distinct '/' || owner || '/' || name || '/documentation' as url
                from packages p
                join repositories r on r.package_id = p.id
                join versions v on v.package_id = p.id
                where
                v.spi_manifest::text like '%documentation_targets%'
                and v.latest is not null
                and (stars >= 200 or owner in ('apple', 'swiftlang', 'swift-server', 'vapor', 'vapor-community', 'GetStream'))
                order by url
                """
    }
    struct Record: Decodable {
        var url: String
    }
    print("# auto-generated via `Run create-restfile \(variant.rawValue)`")
    print("mode: \(mode)")
    print("requests:")
    for r in try await database.raw(query).all(decoding: Record.self) {
        print("""
                \(r.url):
                  url: ${base_url}\(r.url)
                  headers:
                    X-SPI-Smoke-Test: ${smoke_test_token}
                  validation:
                    status: .regex((2|3)\\d\\d)
              """)
    }
}

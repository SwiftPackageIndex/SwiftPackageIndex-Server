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

import Fluent
import Vapor


struct ReconcileCommand: AsyncCommand {
    struct Signature: CommandSignature { }

    var help: String { "Reconcile package list with server" }

    func run(using context: CommandContext, signature: Signature) async throws {
        Current.setLogger(Logger(component: "reconcile"))

        Current.logger()?.info("Reconciling ...")

        do {
            try await reconcile(client: context.application.client,
                                database: context.application.db)
        } catch {
            Current.logger()?.error("\(error.localizedDescription)")
        }

        Current.logger()?.info("done.")

        do {
            try await AppMetrics.push(client: context.application.client, jobName: "reconcile")
        } catch {
            Current.logger()?.warning("\(error.localizedDescription)")
        }
    }
}


func reconcile(client: Client, database: Database) async throws {
    let start = DispatchTime.now().uptimeNanoseconds
    defer { AppMetrics.reconcileDurationSeconds?.time(since: start) }
    async let packageList = try Current.fetchPackageList(client)
    async let currentList = try fetchCurrentPackageList(database)
    try await reconcileLists(db: database,
                             source: packageList,
                             target: currentList)
}


func liveFetchPackageList(_ client: Client) async throws -> [URL] {
   try await client
        .get(Constants.packageListUri)
        .content
        .decode([String].self, using: JSONDecoder())
        .compactMap(URL.init(string:))
}


func fetchCurrentPackageList(_ db: Database) async throws -> [URL] {
    try await Package.query(on: db)
        .field(Package.self, \.$url)
        .all()
        .map(\.url)
        .compactMap(URL.init(string:))
}


func diff(source: [URL], target: [URL]) -> (toAdd: Set<URL>, toDelete: Set<URL>) {
    let s = Set(source)
    let t = Set(target)
    return (toAdd: s.subtracting(t), toDelete: t.subtracting(s))
}


func reconcileLists(db: Database, source: [URL], target: [URL]) async throws {
    let (toAdd, toDelete) = diff(source: source, target: target)
    let insert = toAdd.map { Package(url: $0, processingStage: .reconciliation) }
    try await insert.create(on: db)
    for url in toDelete {
        try await Package.query(on: db)
            .filter(by: url)
            .delete()
    }
}

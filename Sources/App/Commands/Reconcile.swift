// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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


struct ReconcileCommand: Command {
    struct Signature: CommandSignature { }
    
    var help: String { "Reconcile package list with server" }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = Logger(component: "reconcile")

        logger.info("Reconciling ...")
        let request = try reconcile(client: context.application.client,
                                    database: context.application.db)
        try request.wait()
    }
}


func reconcile(client: Client, database: Database) throws -> EventLoopFuture<Void> {
    let packageList = try Current.fetchPackageList(client)
    let currentList = try fetchCurrentPackageList(database)
    
    return packageList.and(currentList)
        .flatMap { reconcileLists(db: database, source: $0, target: $1) }
}


func liveFetchPackageList(_ client: Client) throws -> EventLoopFuture<[URL]> {
    client
        .get(Constants.packageListUri)
        .flatMapThrowing { try $0.content.decode([String].self, using: JSONDecoder()) }
        .flatMapEachCompactThrowing(URL.init(string:))
}


func fetchCurrentPackageList(_ db: Database) throws -> EventLoopFuture<[URL]> {
    db.query(Package.self)
        .all()
        .mapEach(\.url)
        .mapEachCompact(URL.init(string:))
}


func diff(source: [URL], target: [URL]) -> (toAdd: Set<URL>, toDelete: Set<URL>) {
    let s = Set(source)
    let t = Set(target)
    return (toAdd: s.subtracting(t), toDelete: t.subtracting(s))
}


func reconcileLists(db: Database, source: [URL], target: [URL]) -> EventLoopFuture<Void> {
    let (toAdd, toDelete) = diff(source: source, target: target)
    let insert = toAdd.map { Package(url: $0, processingStage: .reconciliation) }.create(on: db)
    let delete = toDelete
        .map { url in
            Package.query(on: db)
                .filter(by: url)
                .delete()
        }.flatten(on: db.eventLoop)
    return insert.and(delete).transform(to: ())
}

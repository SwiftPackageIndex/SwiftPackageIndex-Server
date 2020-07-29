import Fluent
import Vapor


extension Build {

    static func query(on database: Database, buildId: Build.Id) -> EventLoopFuture<Build> {
        Build.query(on: database)
            .filter(\.$id == buildId)
            .with(\.$version) {
                $0.with(\.$package) {
                    $0.with(\.$repositories)
                }
            }
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { build in
                // load all versions in order to resolve package name
                build.version.package.$versions.load(on: database).map { build }
            }
    }

}

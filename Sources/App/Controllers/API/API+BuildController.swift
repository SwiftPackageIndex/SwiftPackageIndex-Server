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
import PostgresKit
import Vapor


extension API {

    enum BuildController {
        static func buildReport(req: Request) async throws -> HTTPStatus {
            let dto = try req.content.decode(PostBuildReportDTO.self)
            let version = try await App.Version
                .find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))

            do {  // update build
                  // Find or create build for updating.
                  // We look up by default, because the common case is that a build stub
                  // is present.
                let build = try await Build.find(dto.buildId, on: req.db)
                ?? Build(id: dto.buildId,
                         version: version,
                         platform: dto.platform,
                         status: dto.status,
                         swiftVersion: dto.swiftVersion)
                build.buildCommand = dto.buildCommand
                build.buildDuration = dto.buildDuration
                build.buildErrors = dto.buildErrors
                build.builderVersion = dto.builderVersion
                build.jobUrl = dto.jobUrl
                build.logUrl = dto.logUrl
                build.platform = dto.platform
                build.runnerId = dto.runnerId
                build.status = dto.status
                build.swiftVersion = dto.swiftVersion
                do {
                    try await build.save(on: req.db)
                } catch let error as PSQLError where error.isUniqueViolation {
                    // Try and delete the conflicting build
                    let conflictingBuild = try await Build.query(on: req.db,
                                                                 platform: dto.platform,
                                                                 swiftVersion: dto.swiftVersion,
                                                                 versionId: version.requireID())
                    try await conflictingBuild?.delete(on: req.db)
                    // Try saving one more time
                    do {
                        try await build.save(on: req.db)
                    } catch let error as PSQLError where error.isUniqueViolation {
                        // We could simply let this propagate but this is easier to diagnose
                        // (although it should technically be impossible to actually occur
                        // since we are explicitly querying for the record to update rather
                        // than saving without checking for conflict first.)
                        return .conflict
                    }
                }

                AppMetrics.apiBuildReportTotal?.inc(1, .buildReportLabels(build))
                if build.status == .infrastructureError {
                    req.logger.critical("build infrastructure error: \(build.jobUrl)")
                }
            }

            do {  // update version and package
                switch (dto.productDependencies, dto.resolvedDependencies) {
                    case (.none, .none):
                        break
                    case let (productDependencies, resolvedDependencies):
                        version.productDependencies = productDependencies
                        version.resolvedDependencies = resolvedDependencies
                        try await version.save(on: req.db)
                }

                // it's ok to reach through $package to get its id, because `$package.id`
                // is actually `versions.package_id` and therefore loaded
                try await Package.updatePlatformCompatibility(for: version.$package.id, on: req.db)
            }

            return .noContent
        }

        static func docReport(req: Request) async throws -> HTTPStatus {
            let dto = try req.content.decode(PostDocReportDTO.self)
            let buildId = try req.parameters.get("id")
                .flatMap(UUID.init(uuidString:))
                .unwrap(or: Abort(.badRequest))
            let build = try await Build.find(buildId, on: req.db)
                .unwrap(or: Abort(.notFound))

            // Upsert build.docUpload
            do {
                try await DocUpload(dto: dto).attach(to: build, on: req.db)
            } catch let error as PSQLError where error.isUniqueViolation {
                // Find the conflicting DocUpload via the version_id. The doc upload could have
                // moved to a different build, which is why we filter via the version.
                // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2280
                try await req.db.transaction { tx in
                    let existingDocUploads = try await DocUpload.query(on: tx)
                        .join(Build.self, on: \Build.$id == \DocUpload.$build.$id)
                        .filter(Build.self, \.$version.$id == build.$version.id)
                        .all()
                    for d in existingDocUploads {
                        try await d.detachAndDelete(on: tx)
                    }
                    try await DocUpload(dto: dto).attach(to: build, on: tx)
                }
            } catch {
                req.logger.critical("\(error)")
                throw error
            }

            // Update build.version.docArchives
            if let docArchives = dto.docArchives {
                try await App.Version.query(on: req.db)
                .set(\.$docArchives, to: docArchives)
                    .filter(\.$id == build.$version.id)
                    .update()
            }

            return .noContent
        }
    }

}


private extension DocUpload {
    convenience init(dto: API.PostDocReportDTO) {
        self.init(
            id: .init(),
            error: dto.error,
            fileCount: dto.fileCount,
            linkablePathsCount: dto.linkablePathsCount,
            logUrl: dto.logUrl,
            mbSize: dto.mbSize,
            status: dto.status
        )
    }
}

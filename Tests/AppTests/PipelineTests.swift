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

@testable import App

import Dependencies
import SQLKit
import Testing
import Vapor


// Tests concerning the full pipeline of operations:
// - candidate selection at each stage
// - processing stage recording
// - error recording
extension AllTests.PipelineTests {

    @Test func fetchCandidates_ingestion_fifo() async throws {
        // oldest first
        try await withApp { app in
            try await [
                Package(url: "1", status: .ok, processingStage: .reconciliation),
                Package(url: "2", status: .ok, processingStage: .reconciliation),
            ].save(on: app.db)

            try await withDependencies {
                // fast forward our clock by the deadtime interval
                $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime)
            } operation: {
                let batch = try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10)
                #expect(batch.map(\.model.url) == ["1", "2"])
            }
        }
    }

    @Test func fetchCandidates_ingestion_limit() async throws {
        try await withApp { app in
            try await [
                Package(url: "1", status: .ok, processingStage: .reconciliation),
                Package(url: "2", status: .ok, processingStage: .reconciliation),
            ].save(on: app.db)

            try await withDependencies {
                // fast forward our clock by the deadtime interval
                $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime)
            } operation: {
                let batch = try await Package.fetchCandidates(app.db, for: .ingestion, limit: 1)
                #expect(batch.map(\.model.url) == ["1"])
            }
        }
    }

    @Test func fetchCandidates_ingestion_correct_stage() async throws {
        // only pick up from reconciliation stage
        try await withApp { app in
            try await [
                Package(url: "1", status: .ok, processingStage: nil),
                Package(url: "2", status: .ok, processingStage: .reconciliation),
                Package(url: "3", status: .ok, processingStage: .analysis),
            ].save(on: app.db)

            try await withDependencies {
                $0.date.now = .now
            } operation: {
                let batch = try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10)
                #expect(batch.map(\.model.url) == ["2"])
            }
        }
    }

    @Test func fetchCandidates_ingestion_prefer_new() async throws {
        // make sure records with status = new come first, then least recent
        try await withApp { app in
            try await [
                Package(url: "1", status: .notFound, processingStage: .reconciliation),
                Package(url: "2", status: .new, processingStage: .reconciliation),
                Package(url: "3", status: .ok, processingStage: .reconciliation),
            ].save(on: app.db)

            try await withDependencies {
                // fast forward our clock by the deadtime interval
                $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime)
            } operation: {
                let batch = try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10)
                #expect(batch.map(\.model.url) == ["2", "1", "3"])
            }
        }
    }

    @Test func fetchCandidates_ingestion_eventual_refresh() async throws {
        // Make sure packages in .analysis stage get re-ingested after a while to
        // check for upstream package changes
        try await withApp { app in
            try await [
                Package(url: "1", status: .ok, processingStage: .analysis),
                Package(url: "2", status: .ok, processingStage: .analysis),
            ].save(on: app.db)
            let p2 = try await Package.query(on: app.db).filter(by: "2").first()!
            try await (app.db as! SQLDatabase).raw(
                "update packages set updated_at = updated_at - interval '91 mins' where id = \(bind: p2.id)"
            ).run()

            try await withDependencies {
                $0.date.now = .now
            } operation: {
                let batch = try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10)
                #expect(batch.map(\.model.url) == ["2"])
            }
        }
    }

    @Test func fetchCandidates_ingestion_refresh_analysis_only() async throws {
        // Ensure we only pick up .analysis stage records on the refresh cycle *) - we don't
        // want to refresh .ingestion stage records that have lagged in analysis, because it
        // resets their `.new` state prematurely.
        //
        // *) in addition to the .reconciliation ones, which we always pick up, regardless of
        // ingestion dead time.
        try await withApp { app in
            try await [
                Package(url: "1", status: .new, processingStage: .reconciliation),
                Package(url: "2", status: .new, processingStage: .ingestion),
                Package(url: "3", status: .new, processingStage: .analysis),
            ].save(on: app.db)

            try await withDependencies {
                // fast forward our clock by the deadtime interval
                $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime)
            } operation: {
                let batch = try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10)
                #expect(batch.map(\.model.url) == ["1", "3"])
            }
        }
    }

    @Test func fetchCandidates_analysis_correct_stage() async throws {
        // only pick up from ingestion stage
        try await withApp { app in
            try await [
                Package(url: "1", status: .ok, processingStage: nil),
                Package(url: "2", status: .ok, processingStage: .reconciliation),
                Package(url: "3", status: .ok, processingStage: .ingestion),
                Package(url: "4", status: .ok, processingStage: .analysis),
            ].save(on: app.db)
            let batch = try await Package.fetchCandidates(app.db, for: .analysis, limit: 10)
            #expect(batch.map(\.model.url) == ["3"])
        }
    }

    @Test func fetchCandidates_analysis_prefer_new() async throws {
        // Test pick up from ingestion stage with status = new first, then FIFO
        try await withApp { app in
            try await [
                Package(url: "1", status: .notFound, processingStage: .ingestion),
                Package(url: "2", status: .ok, processingStage: .ingestion),
                Package(url: "3", status: .analysisFailed, processingStage: .ingestion),
                Package(url: "4", status: .new, processingStage: .ingestion),
            ].save(on: app.db)
            let batch = try await Package.fetchCandidates(app.db, for: .analysis, limit: 10)
            #expect(batch.map(\.model.url) == ["4", "1", "2", "3"])
        }
    }

    @Test func processing_pipeline() async throws {
        // Test pipeline pick-up end to end
        let urls = ["1", "2", "3"].asGithubUrls
        try await withDependencies {
            $0.date.now = .now
            $0.environment.loadSPIManifest = { _ in nil }
            $0.fileManager.fileExists = { @Sendable _ in true }
            $0.git.commitCount = { @Sendable _ in 12 }
            $0.git.firstCommitDate = { @Sendable _ in .t0 }
            $0.git.getTags = { @Sendable _ in [] }
            $0.git.hasBranch = { @Sendable _, _ in true }
            $0.git.lastCommitDate = { @Sendable _ in .t1 }
            $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha", date: .t0) }
            $0.git.shortlog = { @Sendable _ in
                """
                10\tPerson 1
                 2\tPerson 2
                """
            }
            $0.github.fetchLicense = { @Sendable _, _ in nil }
            $0.github.fetchMetadata = { @Sendable owner, repository in .mock(owner: owner, repository: repository) }
            $0.github.fetchReadme = { @Sendable _, _ in nil }
            $0.packageListRepository.fetchPackageList = { @Sendable _ in urls.asURLs }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
            $0.packageListRepository.fetchCustomCollections = { @Sendable _ in [] }
            $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in [] }
            $0.shell.run = { @Sendable cmd, path in
                if cmd.description.hasSuffix("swift package dump-package") {
                    return #"{ "name": "Mock", "products": [], "targets": [] }"#
                }
                return ""
            }
        } operation: {
            try await withApp { app in
                // MUT - first stage
                try await reconcile(client: app.client, database: app.db)
                
                do {  // validate
                    let packages = try await Package.query(on: app.db).sort(\.$url).all()
                    #expect(packages.map(\.url) == ["1", "2", "3"].asGithubUrls)
                    #expect(packages.map(\.status) == [.new, .new, .new])
                    #expect(packages.map(\.processingStage) == [.reconciliation, .reconciliation, .reconciliation])
                    #expect(packages.map(\.isNew) == [true, true, true])
                }
                
                // MUT - second stage
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))
                
                do { // validate
                    let packages = try await Package.query(on: app.db).sort(\.$url).all()
                    #expect(packages.map(\.url) == ["1", "2", "3"].asGithubUrls)
                    #expect(packages.map(\.status) == [.new, .new, .new])
                    #expect(packages.map(\.processingStage) == [.ingestion, .ingestion, .ingestion])
                    #expect(packages.map(\.isNew) == [true, true, true])
                }
                
                // MUT - third stage
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))
                
                do { // validate
                    let packages = try await Package.query(on: app.db).sort(\.$url).all()
                    #expect(packages.map(\.url) == ["1", "2", "3"].asGithubUrls)
                    #expect(packages.map(\.status) == [.ok, .ok, .ok])
                    #expect(packages.map(\.processingStage) == [.analysis, .analysis, .analysis])
                    #expect(packages.map(\.isNew) == [false, false, false])
                }
                
                try await withDependencies {
                    // Now we've got a new package and a deletion
                    $0.packageListRepository.fetchPackageList = { @Sendable _ in ["1", "3", "4"].asGithubUrls.asURLs }
                } operation: {
                    // MUT - reconcile again
                    try await reconcile(client: app.client, database: app.db)
                    
                    do {  // validate - only new package moves to .reconciliation stage
                        let packages = try await Package.query(on: app.db).sort(\.$url).all()
                        #expect(packages.map(\.url) == ["1", "3", "4"].asGithubUrls)
                        #expect(packages.map(\.status) == [.ok, .ok, .new])
                        #expect(packages.map(\.processingStage) == [.analysis, .analysis, .reconciliation])
                        #expect(packages.map(\.isNew) == [false, false, true])
                    }
                    
                    // MUT - ingest again
                    try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))
                    
                    do {  // validate - only new package moves to .ingestion stage
                        let packages = try await Package.query(on: app.db).sort(\.$url).all()
                        #expect(packages.map(\.url) == ["1", "3", "4"].asGithubUrls)
                        #expect(packages.map(\.status) == [.ok, .ok, .new])
                        #expect(packages.map(\.processingStage) == [.analysis, .analysis, .ingestion])
                        #expect(packages.map(\.isNew) == [false, false, true])
                    }
                    
                    // MUT - analyze again
                    let lastAnalysis = Date.now
                    try await Analyze.analyze(client: app.client,
                                              database: app.db,
                                              mode: .limit(10))
                    
                    do {  // validate - only new package moves to .ingestion stage
                        let packages = try await Package.query(on: app.db).sort(\.$url).all()
                        #expect(packages.map(\.url) == ["1", "3", "4"].asGithubUrls)
                        #expect(packages.map(\.status) == [.ok, .ok, .ok])
                        #expect(packages.map(\.processingStage) == [.analysis, .analysis, .analysis])
                        #expect(packages.map { $0.updatedAt! > lastAnalysis } == [false, false, true])
                        #expect(packages.map(\.isNew) == [false, false, false])
                    }
                    
                    try await withDependencies {
                        // fast forward our clock by the deadtime interval
                        $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime)
                    } operation: {
                        // MUT - ingest yet again
                        try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))
                        
                        do {  // validate - now all three packages should have been updated
                            let packages = try await Package.query(on: app.db).sort(\.$url).all()
                            #expect(packages.map(\.url) == ["1", "3", "4"].asGithubUrls)
                            #expect(packages.map(\.status) == [.ok, .ok, .ok])
                            #expect(packages.map(\.processingStage) == [.ingestion, .ingestion, .ingestion])
                            #expect(packages.map(\.isNew) == [false, false, false])
                        }
                        
                        // MUT - re-run analysis to complete the sequence
                        try await Analyze.analyze(client: app.client,
                                                  database: app.db,
                                                  mode: .limit(10))
                        
                        do {  // validate - only new package moves to .ingestion stage
                            let packages = try await Package.query(on: app.db).sort(\.$url).all()
                            #expect(packages.map(\.url) == ["1", "3", "4"].asGithubUrls)
                            #expect(packages.map(\.status) == [.ok, .ok, .ok])
                            #expect(packages.map(\.processingStage) == [.analysis, .analysis, .analysis])
                            #expect(packages.map(\.isNew) == [false, false, false])
                        }
                        
                        // at this point we've ensured that retriggering ingestion after the deadtime will
                        // refresh analysis as expected
                    }
                }
            }
        }
    }

}

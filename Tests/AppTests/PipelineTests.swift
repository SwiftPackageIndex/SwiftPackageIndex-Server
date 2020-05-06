@testable import App

import Vapor
import XCTest


// Tests concerning the full pipeline of operations:
// - candidate selection at each stage
// - processing stage recording
// - error recording
class PipelineTests: AppTestCase {

    func test_fetchCandidates_ingestion_fifo() throws {
        // oldest first
        try  [
            Package(url: "1".url, status: .ok, processingStage: .reconciliation),
            Package(url: "2".url, status: .ok, processingStage: .reconciliation),
            ].save(on: app.db).wait()
        let batch = try Package.fetchCandidates(app.db, for: .ingestion, limit: 10).wait()
        XCTAssertEqual(batch.map(\.url), ["1", "2"])
    }

    func test_fetchCandidates_ingestion_limit() throws {
        try  [
            Package(url: "1".url, status: .ok, processingStage: .reconciliation),
            Package(url: "2".url, status: .ok, processingStage: .reconciliation),
            ].save(on: app.db).wait()
        let batch = try Package.fetchCandidates(app.db, for: .ingestion, limit: 1).wait()
        XCTAssertEqual(batch.map(\.url), ["1"])
    }

    func test_fetchCandidates_ingestion_correct_stage() throws {
        // only pick up from reconciliation stage
        try  [
            Package(url: "1".url, status: .ok, processingStage: nil),
            Package(url: "2".url, status: .ok, processingStage: .reconciliation),
            Package(url: "3".url, status: .ok, processingStage: .analysis),
            ].save(on: app.db).wait()
        let batch = try Package.fetchCandidates(app.db, for: .ingestion, limit: 10).wait()
        XCTAssertEqual(batch.map(\.url), ["2"])
    }

    func test_fetchCandidates_ingestion_prefer_ok() throws {
        // make sure records with status != .ok go to the end (to avoid blocking good
        // records)
        // (reonciliation does not currently actually report back any status != ok but
        // we'll account for it doing so at no harm potentially in the future.)
        try  [
            Package(url: "1".url, status: .notFound, processingStage: .reconciliation),
            Package(url: "2".url, status: .none, processingStage: .reconciliation),
            Package(url: "3".url, status: .ok, processingStage: .reconciliation),
            ].save(on: app.db).wait()
        let batch = try Package.fetchCandidates(app.db, for: .ingestion, limit: 10).wait()
        XCTAssertEqual(batch.map(\.url), ["3", "1", "2"])
    }

    func test_fetchCandidates_analysis_correct_stage() throws {
        // only pick up from ingestion stage
        try  [
            Package(url: "1".url, status: .ok, processingStage: nil),
            Package(url: "2".url, status: .ok, processingStage: .reconciliation),
            Package(url: "3".url, status: .ok, processingStage: .ingestion),
            Package(url: "4".url, status: .ok, processingStage: .analysis),
            ].save(on: app.db).wait()
        let batch = try Package.fetchCandidates(app.db, for: .analysis, limit: 10).wait()
        XCTAssertEqual(batch.map(\.url), ["3"])
    }

    func test_fetchCandidates_analysis_prefer_ok() throws {
        // only pick up from ingestion stage
        try  [
            Package(url: "1".url, status: .notFound, processingStage: .ingestion),
            Package(url: "2".url, status: .ok, processingStage: .ingestion),
            Package(url: "3".url, status: .analysisFailed, processingStage: .ingestion),
            Package(url: "4".url, status: .ok, processingStage: .ingestion),
            ].save(on: app.db).wait()
        let batch = try Package.fetchCandidates(app.db, for: .analysis, limit: 10).wait()
        XCTAssertEqual(batch.map(\.url), ["2", "4", "1", "3"])
    }

    func test_prevent_churn() throws {
        // TODO: figure out some tests around preventing churn, i.e. continuously updating the
        // same rows because they get selected over and over again.
        // If this is even a problem. We *do* want to reselect rows, because they might have
        // changed upstream. But perhaps not too often?
    }
}

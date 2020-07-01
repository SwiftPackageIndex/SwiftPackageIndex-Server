@testable import App

import XCTest

class SemVerTests: XCTestCase {
    
    func test_semVerRegex_valid() throws {
        XCTAssert(semVerRegex.matches("0.0.4"))
        XCTAssert(semVerRegex.matches("1.2.3"))
        XCTAssert(semVerRegex.matches("10.20.30"))
        XCTAssert(semVerRegex.matches("1.1.2-prerelease+meta"))
        XCTAssert(semVerRegex.matches("1.1.2+meta"))
        XCTAssert(semVerRegex.matches("1.1.2+meta-valid"))
        XCTAssert(semVerRegex.matches("1.0.0-alpha"))
        XCTAssert(semVerRegex.matches("1.0.0-beta"))
        XCTAssert(semVerRegex.matches("1.0.0-alpha.beta"))
        XCTAssert(semVerRegex.matches("1.0.0-alpha.beta.1"))
        XCTAssert(semVerRegex.matches("1.0.0-alpha.1"))
        XCTAssert(semVerRegex.matches("1.0.0-alpha0.valid"))
        XCTAssert(semVerRegex.matches("1.0.0-alpha.0valid"))
        XCTAssert(semVerRegex.matches("1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay"))
        XCTAssert(semVerRegex.matches("1.0.0-rc.1+build.1"))
        XCTAssert(semVerRegex.matches("2.0.0-rc.1+build.123"))
        XCTAssert(semVerRegex.matches("1.2.3-beta"))
        XCTAssert(semVerRegex.matches("10.2.3-DEV-SNAPSHOT"))
        XCTAssert(semVerRegex.matches("1.2.3-SNAPSHOT-123"))
        XCTAssert(semVerRegex.matches("1.0.0"))
        XCTAssert(semVerRegex.matches("2.0.0"))
        XCTAssert(semVerRegex.matches("1.1.7"))
        XCTAssert(semVerRegex.matches("2.0.0+build.1848"))
        XCTAssert(semVerRegex.matches("2.0.1-alpha.1227"))
        XCTAssert(semVerRegex.matches("1.0.0-alpha+beta"))
        XCTAssert(semVerRegex.matches("1.2.3----RC-SNAPSHOT.12.9.1--.12+788"))
        XCTAssert(semVerRegex.matches("1.2.3----R-S.12.9.1--.12+meta"))
        XCTAssert(semVerRegex.matches("1.2.3----RC-SNAPSHOT.12.9.1--.12"))
        XCTAssert(semVerRegex.matches("1.0.0+0.build.1-rc.10000aaa-kk-0.1"))
        XCTAssert(semVerRegex.matches("99999999999999999999999.999999999999999999.99999999999999999"))
        XCTAssert(semVerRegex.matches("1.0.0-0A.is.legal"))
    }
    
    func test_allow_leading_v() throws {
        XCTAssert(semVerRegex.matches("v0.0.4"))
    }
    
    func test_semVerRegex_invalid() throws {
        XCTAssertFalse(semVerRegex.matches("1"))
        XCTAssertFalse(semVerRegex.matches("1.2"))
        XCTAssertFalse(semVerRegex.matches("1.2.3-0123"))
        XCTAssertFalse(semVerRegex.matches("1.2.3-0123.0123"))
        XCTAssertFalse(semVerRegex.matches("1.1.2+.123"))
        XCTAssertFalse(semVerRegex.matches("+invalid"))
        XCTAssertFalse(semVerRegex.matches("-invalid"))
        XCTAssertFalse(semVerRegex.matches("-invalid+invalid"))
        XCTAssertFalse(semVerRegex.matches("-invalid.01"))
        XCTAssertFalse(semVerRegex.matches("alpha"))
        XCTAssertFalse(semVerRegex.matches("alpha.beta"))
        XCTAssertFalse(semVerRegex.matches("alpha.beta.1"))
        XCTAssertFalse(semVerRegex.matches("alpha.1"))
        XCTAssertFalse(semVerRegex.matches("alpha+beta"))
        XCTAssertFalse(semVerRegex.matches("alpha_beta"))
        XCTAssertFalse(semVerRegex.matches("alpha."))
        XCTAssertFalse(semVerRegex.matches("alpha.."))
        XCTAssertFalse(semVerRegex.matches("beta"))
        XCTAssertFalse(semVerRegex.matches("1.0.0-alpha_beta"))
        XCTAssertFalse(semVerRegex.matches("-alpha."))
        XCTAssertFalse(semVerRegex.matches("1.0.0-alpha.."))
        XCTAssertFalse(semVerRegex.matches("1.0.0-alpha..1"))
        XCTAssertFalse(semVerRegex.matches("1.0.0-alpha...1"))
        XCTAssertFalse(semVerRegex.matches("1.0.0-alpha....1"))
        XCTAssertFalse(semVerRegex.matches("1.0.0-alpha.....1"))
        XCTAssertFalse(semVerRegex.matches("1.0.0-alpha......1"))
        XCTAssertFalse(semVerRegex.matches("1.0.0-alpha.......1"))
        XCTAssertFalse(semVerRegex.matches("01.1.1"))
        XCTAssertFalse(semVerRegex.matches("1.01.1"))
        XCTAssertFalse(semVerRegex.matches("1.1.01"))
        XCTAssertFalse(semVerRegex.matches("1.2"))
        XCTAssertFalse(semVerRegex.matches("1.2.3.DEV"))
        XCTAssertFalse(semVerRegex.matches("1.2-SNAPSHOT"))
        XCTAssertFalse(semVerRegex.matches("1.2.31.2.3----RC-SNAPSHOT.12.09.1--..12+788"))
        XCTAssertFalse(semVerRegex.matches("1.2-RC-SNAPSHOT"))
        XCTAssertFalse(semVerRegex.matches("-1.0.3-gamma+b7718"))
        XCTAssertFalse(semVerRegex.matches("+justmeta"))
        XCTAssertFalse(semVerRegex.matches("9.8.7+meta+meta"))
        XCTAssertFalse(semVerRegex.matches("9.8.7-whatever+meta+meta"))
    }
    
    func test_init() throws {
        XCTAssertEqual(SemVer("1.2.3"), SemVer(1, 2, 3))
        XCTAssertEqual(SemVer("v1.2.3"), SemVer(1, 2, 3))
        XCTAssertEqual(SemVer("1.2.3-rc"), SemVer(1, 2, 3, "rc"))
        XCTAssertEqual(SemVer("v1.2.3-beta1"), SemVer(1, 2, 3, "beta1"))
        XCTAssertEqual(SemVer("v1.2.3-beta1+build5"), SemVer(1, 2, 3, "beta1", "build5"))
        XCTAssertEqual(SemVer(""), nil)
        XCTAssertEqual(SemVer("1"), nil)
        XCTAssertEqual(SemVer("1.2"), nil)
        XCTAssertEqual(SemVer("1.2.3rc"), nil)
        XCTAssertEqual(SemVer("swift-2.2-SNAPSHOT-2016-01-11-a"), nil)
    }
    
    func test_description() throws {
        XCTAssertEqual(SemVer("1.2.3")?.description, "1.2.3")
        XCTAssertEqual(SemVer("v1.2.3")?.description, "1.2.3")
        XCTAssertEqual(SemVer("1.2.3-beta1")?.description, "1.2.3-beta1")
        XCTAssertEqual(SemVer("1.2.3-beta1+build")?.description, "1.2.3-beta1+build")
    }
    
    func test_Comparable() throws {
        XCTAssert(SemVer(1, 0, 0) < SemVer(2, 0, 0))
        XCTAssert(SemVer(1, 0, 0) < SemVer(1, 1, 0))
        XCTAssert(SemVer(1, 0, 0) < SemVer(1, 0, 1))
        XCTAssert(SemVer(1, 0, 0, "a") < SemVer(1, 0, 0, "b"))
        XCTAssert(SemVer(1, 0, 0, "a", "a") < SemVer(1, 0, 0, "a", "b"))
    }
    
    func test_isStable() throws {
        XCTAssert(SemVer(1, 0, 0).isStable)
        XCTAssert(SemVer(1, 0, 0, "").isStable)
        XCTAssert(SemVer(1, 0, 0, "", "").isStable)
        XCTAssertFalse(SemVer(1, 0, 0, "a").isStable)
        XCTAssertFalse(SemVer(1, 0, 0, "", "a").isStable)
    }
    
    func test_isMajorRelease() throws {
        XCTAssertTrue(SemVer(1, 0, 0).isMajorRelease)
        XCTAssertFalse(SemVer(1, 0, 0, "b").isMajorRelease)
        XCTAssertFalse(SemVer(0, 0, 1).isMajorRelease)
        XCTAssertFalse(SemVer(0, 0, 1, "b").isMajorRelease)
        XCTAssertFalse(SemVer(0, 1, 0).isMajorRelease)
        XCTAssertFalse(SemVer(0, 1, 0, "b").isMajorRelease)
        XCTAssertFalse(SemVer(0, 1, 1).isMajorRelease)
        XCTAssertFalse(SemVer(0, 0, 0).isMajorRelease)
    }
    
    func test_isMinorRelease() throws {
        XCTAssertFalse(SemVer(1, 0, 0).isMinorRelease)
        XCTAssertFalse(SemVer(1, 0, 0, "b").isMinorRelease)
        XCTAssertFalse(SemVer(0, 0, 1).isMinorRelease)
        XCTAssertFalse(SemVer(0, 0, 1, "b").isMinorRelease)
        XCTAssertTrue(SemVer(0, 1, 0).isMinorRelease)
        XCTAssertFalse(SemVer(0, 1, 0, "b").isMinorRelease)
        XCTAssertFalse(SemVer(0, 1, 1).isMinorRelease)
        XCTAssertFalse(SemVer(0, 0, 0).isMinorRelease)
    }
    
    func test_isPatchRelease() throws {
        XCTAssertFalse(SemVer(1, 0, 0).isPatchRelease)
        XCTAssertFalse(SemVer(1, 0, 0, "b").isPatchRelease)
        XCTAssertTrue(SemVer(0, 0, 1).isPatchRelease)
        XCTAssertFalse(SemVer(0, 0, 1, "b").isPatchRelease)
        XCTAssertFalse(SemVer(0, 1, 0).isPatchRelease)
        XCTAssertFalse(SemVer(0, 1, 0, "b").isPatchRelease)
        XCTAssertTrue(SemVer(0, 1, 1).isPatchRelease)
        XCTAssertFalse(SemVer(0, 0, 0).isPatchRelease)
    }
    
}

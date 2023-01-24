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

@testable import DependencyResolution

import XCTest


/// Tests for utilities and extesions that don't each need a full separate test class
class DependencyResolutionTests: XCTestCase {

    func test_getResolvedDependencies_v1() throws {
        // setup
        struct TestFileManager: DependencyResolution.FileManager {
            func contents(atPath: String) -> Data? {
                Data("""
                    {
                      "object": {
                        "pins": [
                          {
                            "package": "Yams",
                            "repositoryURL": "https://github.com/jpsim/Yams.git",
                            "state": {
                              "branch": null,
                              "revision": "01835dc202670b5bb90d07f3eae41867e9ed29f6",
                              "version": "5.0.1"
                            }
                          }
                        ]
                      },
                      "version": 1
                    }
                    """.utf8)
            }
            func fileExists(atPath: String) -> Bool { true }
        }

        // MUT
        let deps = getResolvedDependencies(TestFileManager(),
                                           at: "path ignored because we mock it")

        // validate
        XCTAssertEqual(deps?.count, 1)
    }

    func test_getResolvedDependencies_v2() throws {
        // setup
        struct TestFileManager: DependencyResolution.FileManager {
            func contents(atPath: String) -> Data? {
                Data("""
                    {
                      "pins" : [
                        {
                          "identity" : "swift-log",
                          "kind" : "remoteSourceControl",
                          "location" : "https://github.com/apple/swift-log.git",
                          "state" : {
                            "revision" : "6fe203dc33195667ce1759bf0182975e4653ba1c",
                            "version" : "1.4.4"
                          }
                        }
                      ],
                      "version" : 2
                    }
                    """.utf8)
            }
            func fileExists(atPath: String) -> Bool { true }
        }

        // MUT
        let deps = getResolvedDependencies(TestFileManager(),
                                           at: "path ignored because we mock it")

        // validate
        XCTAssertEqual(deps?.count, 1)
    }

}

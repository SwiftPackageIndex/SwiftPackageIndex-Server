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

import Testing


extension AllTests.SwiftVersionTests {

    @Test func swiftVerRegex() throws {
        #expect(SwiftVersion.swiftVerRegex.matches("1"))
        #expect(SwiftVersion.swiftVerRegex.matches("1.2"))
        #expect(SwiftVersion.swiftVerRegex.matches("1.2.3"))
        #expect(SwiftVersion.swiftVerRegex.matches("v1"))
        #expect(!SwiftVersion.swiftVerRegex.matches("1."))
        #expect(!SwiftVersion.swiftVerRegex.matches("1.2."))
        #expect(!SwiftVersion.swiftVerRegex.matches("1.2.3-pre"))
    }

    @Test func SwiftVersion_init() throws {
        #expect(SwiftVersion("5") == SwiftVersion(5, 0, 0))
        #expect(SwiftVersion("5.2") == SwiftVersion(5, 2, 0))
        #expect(SwiftVersion("5.2.1") == SwiftVersion(5, 2, 1))
        #expect(SwiftVersion("v5") == SwiftVersion(5, 0, 0))
    }

    @Test func SwiftVersion_Comparable() throws {
        #expect(SwiftVersion("5")! < SwiftVersion("5.1")!)
        #expect(!(SwiftVersion("5")! < SwiftVersion("5.0")!))
        #expect(!(SwiftVersion("5")! > SwiftVersion("5.0")!))
        #expect(SwiftVersion("4.2")! < SwiftVersion("5")!)
    }

    @Test func isCompatible() throws {
        let v4_2 = SwiftVersion(4, 2, 0)
        #expect(v4_2.isCompatible(with: .init(4, 2, 0)))
        #expect(v4_2.isCompatible(with: .init(4, 2, 4)))
        #expect(!v4_2.isCompatible(with: .init(4, 0, 0)))
        #expect(!v4_2.isCompatible(with: .init(5, 0, 0)))
    }

    @Test func latestMajor() throws {
        #expect(SwiftVersion.latest.major == 6)
    }

}

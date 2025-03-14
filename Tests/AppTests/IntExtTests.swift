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


extension AllTests.IntExtTests {

    @Test func pluralizedCount() throws {
        #expect(0.labeled("executable") == "no executables")
        #expect(1.labeled("executable") == "1 executable")
        #expect(2.labeled("executable") == "2 executables")

        #expect(1.labeled("library", plural: "libraries") == "1 library")
        #expect(2.labeled("library", plural: "libraries") == "2 libraries")

        #expect(0.labeled("executable", capitalized: true) == "No executables")
        #expect(0.labeled("library", plural: "libraries", capitalized: true) == "No libraries")
    }

}

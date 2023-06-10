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


extension SwiftVersion {

    /// We have a range of tests that use explicit Swift version numbers `.v5_5`, ... to configure test cases. Whenever we add a new and remove on old Swift version, these tests have to be tediously updated by shifting all number forward by one.
    ///
    /// For example:
    ///
    /// ```swift
    /// // setup
    /// let sb = SignificantBuilds(buildInfo: [
    ///     (.v5_7, .linux, .ok),
    ///     (.v5_6, .macosSpm, .ok),
    ///     (.v5_5, .ios, .failed)
    /// ])
    ///
    /// // MUT
    /// let res = try XCTUnwrap(sb.swiftVersionCompatibility().values)
    ///
    /// // validate
    /// XCTAssertEqual(res.sorted(), [.v5_6, .v5_7])
    /// ```
    ///
    /// would be converted to
    ///
    /// ```swift
    /// // setup
    /// let sb = SignificantBuilds(buildInfo: [
    ///     (.v5_8, .linux, .ok),
    ///     (.v5_7, .macosSpm, .ok),
    ///     (.v5_6, .ios, .failed)
    /// ])
    ///
    /// // MUT
    /// let res = try XCTUnwrap(sb.swiftVersionCompatibility().values)
    ///
    /// // validate
    /// XCTAssertEqual(res.sorted(), [.v5_7, .v5_8])
    /// ```
    ///
    /// Adding these new, test-only shortcuts that map generic variable names `.v1`, `.v2`, ... to Swift version numbers, we can write all tests in terms of these variables instead and only need to adjust the single mapping below whenever we change the range of Swift versions.
    static var v1: Self { .v5_5 }
    static var v2: Self { .v5_6 }
    static var v3: Self { .v5_7 }
    static var v4: Self { .v5_8 }

}

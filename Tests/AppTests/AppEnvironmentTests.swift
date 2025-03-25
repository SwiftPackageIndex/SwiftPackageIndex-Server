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
import Testing
import Vapor


extension AllTests.AppEnvironmentTests {

    @Test func Filemanager_checkoutsDirectory() throws {
        withDependencies {
            $0.fileManager.checkoutsDirectory = FileManagerClient.liveValue.checkoutsDirectory
        } operation: {
            unsetenv("CHECKOUTS_DIR")
            @Dependency(\.fileManager) var fileManager
            #expect(fileManager.checkoutsDirectory() == DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts")
            setenv("CHECKOUTS_DIR", "/tmp/foo", 1)
            #expect(fileManager.checkoutsDirectory() == "/tmp/foo")
        }
    }

    @Test func maintenanceMessage() throws {
        defer { unsetenv("MAINTENANCE_MESSAGE") }
        withDependencies {
            $0.environment.maintenanceMessage = EnvironmentClient.liveValue.maintenanceMessage
        } operation: {
            @Dependency(\.environment) var environment
            do {
                unsetenv("MAINTENANCE_MESSAGE")
                #expect(environment.maintenanceMessage() == nil)
            }
            do {
                setenv("MAINTENANCE_MESSAGE", "foo", 1)
                #expect(environment.maintenanceMessage() == "foo")
            }
            do {
                setenv("MAINTENANCE_MESSAGE", "", 1)
                #expect(environment.maintenanceMessage() == nil)
            }
            do {
                setenv("MAINTENANCE_MESSAGE", " ", 1)
                #expect(environment.maintenanceMessage() == nil)
            }
            do {
                setenv("MAINTENANCE_MESSAGE", " \t\n ", 1)
                #expect(environment.maintenanceMessage() == nil)
            }
        }
    }

}

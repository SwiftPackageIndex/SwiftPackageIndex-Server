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

import Fluent
import Testing


extension AllTests.AllMigrationsTests {

    @Test func names_areUnique() throws {
        // The `migrations` table keys off `Migration.name`, so a duplicate entry would be recorded
        // as applied by whichever copy ran first and the other would silently never run.
        let names = AllMigrations.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

}

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

struct SearchFilterPredicate: Equatable {
    var `operator`: SearchFilterComparison
    var value: String

#if DEBUG
    // purely used in testing to instatiate an instance for comparison
    init(operator: SearchFilterComparison, value: String) {
        self.operator = `operator`
        self.value = value
    }
#endif

    init?(searchTerm: String) {
        guard let op = SearchFilterComparison(searchTerm: searchTerm) else {
            return nil
        }
        self.operator = op
        self.value = String(searchTerm.dropFirst(self.`operator`.parseLength))
        guard !self.value.isEmpty else { return nil }
    }
}

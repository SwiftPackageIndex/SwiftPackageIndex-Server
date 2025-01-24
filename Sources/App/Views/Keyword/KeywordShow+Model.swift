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

extension KeywordShow {
    struct Model {
        var keyword: String
        var packages: [PackageInfo]
        var page: Int
        var hasMoreResults: Bool
        let totalPackageCount: Int

        internal init(keyword: String,
                      packages: [PackageInfo],
                      page: Int,
                      hasMoreResults: Bool,
                      totalPackageCount: Int) {
            self.keyword = keyword
            self.packages = packages
            self.page = page
            self.hasMoreResults = hasMoreResults
            self.totalPackageCount = totalPackageCount
        }
    }
}

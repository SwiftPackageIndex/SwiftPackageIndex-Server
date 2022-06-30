// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Foundation

import SotoS3


struct Environment {
    var getFileContent: (_ s3: S3, _ key: S3.StoreKey) async throws -> Data?
    var listFolders: (_ s3: S3, _ key: S3.StoreKey) async throws -> [String]
}


extension Environment {
    static let live = Environment(
        getFileContent: { s3, key in try await s3.getFileContent(key: key) },
        listFolders: { s3, key in try await s3.listFolders(key: key) }
    )
}


#if DEBUG
var Current: Environment = .live
#else
let Current: Environment = .live
#endif



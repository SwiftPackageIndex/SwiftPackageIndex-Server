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

import Foundation

import Dependencies
import S3Store


extension S3Store.Key {
    static func readme(owner: String, repository: String, imageUrl: String? = nil) throws(S3Readme.Error) -> Self {
        @Dependency(\.environment) var environment
        guard let bucket = environment.awsReadmeBucket() else { throw .envVariableNotSet("AWS_README_BUCKET") }

        if let imageUrl {
            guard let url = URL(string: imageUrl) else { throw .invalidURL(imageUrl) }
            let filename = url.lastPathComponent
            let path = "\(owner)/\(repository)/\(filename)".lowercased()
            return .init(bucket: bucket, path: path)
        } else {
            let path = "\(owner)/\(repository)/readme.html".lowercased()
            return .init(bucket: bucket, path: path)
        }
    }
}

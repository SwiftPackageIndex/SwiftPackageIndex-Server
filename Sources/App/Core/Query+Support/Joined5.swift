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

import FluentKit


struct Joined5<M: Model, R1: Joinable, R2: Joinable, R3: Joinable, R4: Joinable>: ModelInitializable {
    private(set) var model: M
}


extension Joined5 {
    var relation1: R1? { try? model.joined(R1.self) }
    var relation2: R2? { try? model.joined(R2.self) }
    var relation3: R3? { try? model.joined(R3.self) }
    var relation4: R4? { try? model.joined(R4.self) }
}

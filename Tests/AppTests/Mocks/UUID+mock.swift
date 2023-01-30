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


// periphery:ignore
extension UUID {
    static var id0: Self { UUID(uuidString: "5974d34d-b2b9-4cdb-9580-e1ac74cb579d")! }
    static var id1: Self { UUID(uuidString: "e879173a-dc19-4949-8014-f7b6dafbf0ce")! }
    static var id2: Self { UUID(uuidString: "85b10001-0f52-4560-bda6-a4b11d910675")! }
    static var id3: Self { UUID(uuidString: "1dfda954-74b2-4d07-8477-133fd0538b9a")! }
    static var id4: Self { UUID(uuidString: "9faf39e2-7fc5-498d-a0a9-dd4ea0db56f5")! }
    static var id5: Self { UUID(uuidString: "6c3af1e6-1cfb-4564-bce4-3b1ecc974f78")! }
    static var id6: Self { UUID(uuidString: "4c8cd78b-dfae-438f-88ed-7303cf963170")! }
    static var id7: Self { UUID(uuidString: "cca945dd-0546-4c64-a498-bb7742660f8a")! }
    static var id8: Self { UUID(uuidString: "9c288246-ac47-4a35-9730-60c281ae590b")! }
    static var id9: Self { UUID(uuidString: "5dcceaa7-5eed-44a7-8309-93758208c178")! }

    static func mockId(at index: Int) -> UUID { mockAll[index] }

    static var mockAll: [Self] {
        [id0, id1, id2, id3, id4, id5, id6, id7, id8, id9]
    }
}

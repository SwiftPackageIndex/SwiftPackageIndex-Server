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

import { Controller } from '@hotwired/stimulus'

export class ReadmeController extends Controller {
    navigateToAnchorFromLocation() {
        // If the browser has an anchor in the URL that may be inside the README then
        // we should attempt to scroll it into view once the README is loaded.
        const hash = window.location.hash
        if (hash == '') return // No anchor on the URL so we do nothing.

        const hashElement = this.element.querySelector(hash)
        if (hashElement) hashElement.scrollIntoView()
    }
}

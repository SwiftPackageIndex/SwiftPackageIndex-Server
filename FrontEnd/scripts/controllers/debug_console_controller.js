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

export class DebugConsoleController extends Controller {
    connect() {
        console.log('DebugConsoleController connected')

        // Debug console is Hidden by default. Make it visble by typing:
        //   `localStorage.setItem('spiDebug', 'true');`
        // into the browser console.
        if (localStorage.getItem('spiDebug') === 'true') {
            this.element.classList.remove('hidden')
        }
    }

    hide() {
        this.element.classList.add('hidden')
    }

    disable() {
        this.element.classList.add('hidden')
        localStorage.setItem('spiDebug', 'false')
    }
}

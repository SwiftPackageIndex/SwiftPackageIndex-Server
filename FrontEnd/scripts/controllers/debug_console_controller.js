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
    static targets = ['grid']

    connect() {
        // Debug console is Hidden by default. Make it visble by typing:
        //   `localStorage.setItem('spiDebug', 'true');`
        // into the browser console.
        if (localStorage.getItem('spiDebug') === 'true') {
            this.element.classList.remove('hidden')

            this.addCanonicalUrls()
        }
    }

    hide() {
        this.element.classList.add('hidden')
    }

    disable() {
        this.element.classList.add('hidden')
        localStorage.setItem('spiDebug', 'false')
    }

    newGridCell(contents) {
        const cellElement = document.createElement('div')
        cellElement.innerText = contents
        return cellElement
    }

    addCanonicalUrls() {
        const canonicalUrl = document.querySelector('link[rel="canonical"]').href
        const windowUrl = window.location.href

        this.gridTarget.appendChild(this.newGridCell('Canonical URL'))
        this.gridTarget.appendChild(this.newGridCell(canonicalUrl))

        this.gridTarget.appendChild(this.newGridCell('Window URL'))
        this.gridTarget.appendChild(this.newGridCell(windowUrl))

        this.gridTarget.appendChild(this.newGridCell('URLs Match'))
        this.gridTarget.appendChild(this.newGridCell(canonicalUrl === windowUrl))
    }
}

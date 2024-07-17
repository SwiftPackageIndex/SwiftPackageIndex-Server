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

export class SPIDebugPanel extends HTMLElement {
    connectedCallback() {
        // Debug console is Hidden by default. Make it visble by typing:
        //   `localStorage.setItem('spiDebug', 'true');`
        // into the browser console.
        if (localStorage.getItem('spiDebug') === 'true') {
            this.classList.remove('hidden')
            this.addCanonicalUrls()
        }

        this.querySelector('.buttons > .hide').addEventListener('click', () => {
            this.classList.add('hidden')
        })

        this.querySelector('.buttons > .disable').addEventListener('click', () => {
            this.classList.add('hidden')
            localStorage.setItem('spiDebug', 'false')
        })
    }

    disconnectedCallback() {
        console.log('SPIDebugPanel disconnectedCallback')
    }

    newTableRow(title, value) {
        const rowElement = document.createElement('tr')

        const titleCellElement = document.createElement('td')
        titleCellElement.innerText = title

        const valueCellElement = document.createElement('td')
        valueCellElement.innerText = value

        rowElement.appendChild(titleCellElement)
        rowElement.appendChild(valueCellElement)
        return rowElement
    }

    addCanonicalUrls() {
        const tableElement = this.querySelector('table')
        const canonicalUrl = document.querySelector('link[rel="canonical"]').href
        const windowUrl = window.location.href

        tableElement.appendChild(this.newTableRow('Canonical URL', canonicalUrl))
        tableElement.appendChild(this.newTableRow('Window URL', windowUrl))
        tableElement.appendChild(this.newTableRow('URLs Match', canonicalUrl === windowUrl))
    }
}

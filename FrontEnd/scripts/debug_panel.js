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

            this.reset()
            this.addButtons()
            this.addCanonicalUrls()
        }
    }

    reset() {
        const buttonsContainer = this.querySelector('.buttons')
        if (buttonsContainer) buttonsContainer.remove()

        const dynamicRowElements = this.querySelectorAll('tr:not([server-side])')
        dynamicRowElements.forEach((row) => row.remove())
    }

    addButtons() {
        const hideButton = document.createElement('button')
        hideButton.innerText = 'Hide'
        hideButton.title = 'Temporarily hide this panel'
        hideButton.addEventListener('click', () => {
            this.classList.add('hidden')
        })

        const disableButton = document.createElement('button')
        disableButton.innerText = 'Disable'
        disableButton.title = 'Disable the debug panel'
        disableButton.addEventListener('click', () => {
            localStorage.setItem('spiDebug', 'false')
            this.classList.add('hidden')
        })

        const buttonsContainer = document.createElement('div')
        buttonsContainer.classList.add('buttons')
        buttonsContainer.appendChild(hideButton)
        buttonsContainer.appendChild(disableButton)
        this.prepend(buttonsContainer)
    }

    newTableRow(title, value, valueCssClass) {
        const tableElement = this.querySelector('table > tbody')
        const rowElement = document.createElement('tr')

        const titleCellElement = document.createElement('td')
        titleCellElement.innerText = title

        const valueSpanElement = document.createElement('span')
        valueSpanElement.innerText = value
        const valueCellElement = document.createElement('td')
        valueCellElement.appendChild(valueSpanElement)
        if (valueCssClass) valueCellElement.classList.add(valueCssClass)

        rowElement.appendChild(titleCellElement)
        rowElement.appendChild(valueCellElement)
        tableElement.appendChild(rowElement)
    }

    addCanonicalUrls() {
        const canonicalUrl = document.querySelector('link[rel="canonical"]')?.href
        const windowUrl = window.location.href
        const matchingCanonicalUrl = canonicalUrl === windowUrl

        this.newTableRow('Canonical URL', canonicalUrl ? canonicalUrl : 'Missing', canonicalUrl ? null : 'red')
        this.newTableRow('Window URL', windowUrl)
        this.newTableRow('Canonical Match', matchingCanonicalUrl, matchingCanonicalUrl ? 'green' : 'red')
    }
}

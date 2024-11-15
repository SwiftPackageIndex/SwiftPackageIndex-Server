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
import mermaid from 'mermaid'

export class ReadmeController extends Controller {
    frameLoaded() {
        this.navigateToAnchorFromLocation()
        this.renderMermaidDiagrams()
    }

    async renderMermaidDiagrams() {
        // Replace all Mermaid chart sources with rendered diagrams.
        const mermaidSectionElements = document.querySelectorAll('section[data-type="mermaid"]')
        for (const [index, mermaidSectionElement] of Array.from(mermaidSectionElements).entries()) {
            // No need to parse the JSON, the chart source is in a `data-plain` attribute.
            const mermaidDataElement = mermaidSectionElement.querySelector('[data-plain]')
            if (!mermaidDataElement) continue
            const chartDefinition = mermaidDataElement.getAttribute('data-plain')
            if (!chartDefinition) continue

            // Make a container with *both* light and dark charts.
            const chartContainer = document.createElement('div')
            chartContainer.classList.add('mermaid-chart')
            mermaidDataElement.appendChild(chartContainer)

            // The documentation says not to call `initialize` more than once. That said, it's
            // the only way to switch themes and therefore the only way to get this working.
            mermaid.initialize({ theme: 'default', nodeSpacing: 50, rankSpacing: 50, curve: 'basis' })
            const lightRenderResult = await mermaid.render(`mermaid-chart-light-${index}`, chartDefinition)
            chartContainer.insertAdjacentHTML('beforeend', lightRenderResult.svg)

            mermaid.initialize({ theme: 'dark', nodeSpacing: 50, rankSpacing: 50, curve: 'basis' })
            const darkRenderResult = await mermaid.render(`mermaid-chart-dark-${index}`, chartDefinition)
            chartContainer.insertAdjacentHTML('beforeend', darkRenderResult.svg)
        }
    }

    navigateToAnchorFromLocation() {
        // If the browser has an anchor in the URL that may be inside the README then
        // we should attempt to scroll it into view once the README is loaded.
        const hash = window.location.hash
        if (hash == '') return // No anchor on the URL so we do nothing.

        const hashElement = this.element.querySelector(hash)
        if (hashElement) hashElement.scrollIntoView()
    }
}

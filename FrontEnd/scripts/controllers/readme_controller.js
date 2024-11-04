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
    onThemeChange(darkMode) {
        // If `darkMode` isn't passed, get the current value
        if (darkMode == undefined) {
            darkMode = window.matchMedia('(prefers-color-scheme: dark)').matches
            console.log('actually dark mode is', darkMode)
        }

        // Get all mermaid diagrams
        const mermaidDivs = document.querySelectorAll('pre[lang="mermaid"]')

        for (const div of Array.from(mermaidDivs)) {
            // Get the diagram code
            const json = div.parentElement.parentElement.getAttribute('data-json')
            if (!json) {
                continue
            }
            const diagramCode = JSON.parse(json).data
            if (diagramCode) {
                try {
                    // Clear the existing diagram
                    div.innerHTML = diagramCode
                    div.removeAttribute('data-processed')
                } catch (error) {
                    console.error('Error re-rendering mermaid diagram:', error)
                }
            }
        }

        mermaid.initialize({
            theme: darkMode ? 'dark' : undefined,
            nodeSpacing: 50,
            rankSpacing: 50,
            curve: 'basis',
        })

        // Rather then preprocess the HTML in Swift we just change the selector to use `lang` attribute instead of `class`
        mermaid.run({
            querySelector: 'pre[lang="mermaid"]',
        })
    }
    navigateToAnchorFromLocation() {
        // listen for changes to color scheme
        if (typeof window !== 'undefined') {
            const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')

            // Add listener for system preference changes
            mediaQuery.addEventListener('change', (e) => {
                this.onThemeChange(e.matches)
            })
        }

        // setup mermaid diagrams
        this.onThemeChange()

        // If the browser has an anchor in the URL that may be inside the README then
        // we should attempt to scroll it into view once the README is loaded.
        const hash = window.location.hash
        if (hash == '') return // No anchor on the URL so we do nothing.

        const hashElement = this.element.querySelector(hash)
        if (hashElement) hashElement.scrollIntoView()
    }
}

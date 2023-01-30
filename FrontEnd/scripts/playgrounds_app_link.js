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

import { measurePlausibleEvent } from './plausible_analytics.js'

export class SPIPlaygroundsAppLinkFallback {
    constructor() {
        document.addEventListener('click', (event) => {
            const linkElement = event.target.findParentMatching((element) => {
                return element.matches('a') && element.protocol === 'spi-playgrounds:'
            })

            if (linkElement) {
                // This link should *never* act as a link otherwise people will see the
                // error page saying the app isn't installed with no opportunity for us
                // to tell them how to continue.
                event.preventDefault()

                // Instead, fake a link inside a page that's never visible by creating
                // an iframe element and having that try to load the app. If the app is
                // not installed, this fails silently.
                const frameElement = document.createElement('iframe')
                frameElement.style.display = 'none'
                frameElement.src = linkElement.href
                linkElement.insertAdjacentElement('afterend', frameElement)
                setTimeout(() => {
                    frameElement.remove()
                }, 1000)

                // Also, because we can never know whether the app opened, display the
                // popover div that links to the download page. Hide it again 5 seconds later.
                const explainerElement = document.getElementById('app-download-explainer')
                explainerElement.classList.remove('hidden')
                setTimeout(() => {
                    explainerElement.classList.add('hidden')
                }, 5000)

                // Trigger an analytics event and pass the dependency as a custom property
                const targetUrl = new URL(linkElement.href)
                const dependencies = targetUrl.searchParams.get('dependencies')
                measurePlausibleEvent('SPI Playgrounds Launch', { props: { dependency: dependencies } })
            }
        })
    }
}

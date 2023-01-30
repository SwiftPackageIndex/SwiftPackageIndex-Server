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

export class TabBarController extends Controller {
    static targets = ['tab', 'content']

    connect() {
        // If the address bar has an anchor that matches a tab, set it active.
        const tabIndex = this.tabTargets.findIndex((tabTarget) => {
            // Strip the '#' character from the location anchor.
            return tabTarget.id === window.location.hash.substring(1)
        })
        if (tabIndex >= 0) this.setIndex(tabIndex, false)

        // If there's still no active tab, set the first tab active.
        const activeTabElement = this.tabTargets.find((element) => element.classList.contains('active'))
        const activeContentElement = this.contentTargets.find((element) => element.classList.contains('active'))
        if (activeTabElement == null || activeContentElement == null) this.setIndex(0, false)
    }

    updateTab(event) {
        const tabIndex = this.tabTargets.indexOf(event.target)
        this.setIndex(tabIndex > 0 ? tabIndex : 0, true)
    }

    setIndex(index, pushHistory) {
        this.tabTargets.forEach((tabTarget, tabIndex) => {
            if (tabIndex === index) {
                tabTarget.classList.add('active')
                if (pushHistory) {
                    // Set the anchor in the address bar to the tab being selected.
                    const currentLocationUrl = new URL(window.location)
                    currentLocationUrl.hash = `#${tabTarget.id}`
                    window.history.pushState({}, '', currentLocationUrl)
                }
            } else {
                tabTarget.classList.remove('active')
            }
        })

        this.contentTargets.forEach((contentTarget, contentIndex) => {
            if (contentIndex === index) {
                contentTarget.classList.add('active')
            } else {
                contentTarget.classList.remove('active')
            }
        })
    }
}

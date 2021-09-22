// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

export class SPITabBarElement extends HTMLElement {
  constructor() {
    super()

    function showPage(tabId) {
      const tabPageElements = document.querySelectorAll('[data-tab-page]')
      tabPageElements.forEach((tabPageElement) => {
        if (tabPageElement.dataset.tabPage == tabId) {
          tabPageElement.classList.remove('hidden')
        } else {
          tabPageElement.classList.add('hidden')
        }
      })
    }

    const tabLinkElements = this.querySelectorAll('[data-tab]')
    tabLinkElements.forEach((tabLinkElement) => {
      // Add click listener which will show the correct page when a user taps on a tab link
      tabLinkElement.addEventListener('click', (event) => {
        // Update Tab Links
        tabLinkElements.forEach((tabLinkElement) => {
          tabLinkElement.classList.remove('active')
        })

        tabLinkElement.classList.add('active')

        // Update Tab Pages
        showPage(event.srcElement.dataset.tab)
      })
    })

    // Show only the page which has the active class, on load
    const activeTabLinkElement = this.querySelector('[data-tab].active')
    showPage(activeTabLinkElement.dataset.tab)
  }
}

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

    function deactivateAllTabs(tabLinkElements) {
      tabLinkElements.forEach((tabLinkElement) => {
        tabLinkElement.classList.remove('active')
      })
    }

    function activateTab(tabLinkElement) {
      tabLinkElement.classList.add('active')
    }

    const locationUrlHash = new URL(window.location).hash
    const tabLinkElements = this.querySelectorAll('[data-tab]')
    tabLinkElements.forEach((tabLinkElement) => {
      // For all tabs, if their name matches the anchor in the location, make it active.
      if (locationUrlHash === `#${tabLinkElement.dataset.tab}`) {
        deactivateAllTabs(tabLinkElements)
        activateTab(tabLinkElement)

        // Scroll the tab bar to the top of the screen.
        // NOTE: This can't be done inline, and this code is brittle based on client network
        // speed having loaded the releases within 500ms. The alternative is to have the releases
        // tab selected and focused, but scrolled into the middle of the screen.
        setTimeout((event) => {
          tabLinkElement.scrollIntoView(true)
        }, 1000)
      }

      // Add click listener which will show the correct page when a user taps on a tab link
      tabLinkElement.addEventListener('click', (event) => {
        // Update Tab Links
        deactivateAllTabs(tabLinkElements)
        activateTab(tabLinkElement)

        // Update Tab Pages
        showPage(event.srcElement.dataset.tab)
      })
    })

    // Show only the page which has the active class, on load
    const activeTabLinkElement = this.querySelector('[data-tab].active')
    showPage(activeTabLinkElement.dataset.tab)
  }
}

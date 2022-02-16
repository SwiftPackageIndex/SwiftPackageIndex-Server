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

    const tabLinkElements = this.querySelectorAll('[data-tab]')
    tabLinkElements.forEach((tabLinkElement) => {
      tabLinkElement.addEventListener('click', (event) => {
        // Assign a new tab to be active and switch to it.
        this.activateTab(tabLinkElement, tabLinkElements)
        this.showPage(event.srcElement.dataset.tab)

        // Only when explicitly clicked, change the page anchor.
        const currentLocationUrl = new URL(window.location)
        currentLocationUrl.hash = `#${tabLinkElement.dataset.tab}`
        window.history.pushState({}, '', currentLocationUrl)
      })
    })

    this.syncTabs()
  }

  syncTabs() {
    const locationUrlHash = new URL(window.location).hash
    const tabLinkElements = this.querySelectorAll('[data-tab]')
    tabLinkElements.forEach((tabLinkElement) => {
      // Make any tab active where the identifier matches an anchor in the location.
      if (locationUrlHash === `#${tabLinkElement.dataset.tab}`) {
        this.activateTab(tabLinkElement, tabLinkElements)
      }
    })

    // Show the page which has the active class.
    const activeTabLinkElement = this.querySelector('[data-tab].active')
    this.showPage(activeTabLinkElement.dataset.tab)
  }

  showPage(tabId) {
    const tabPageElements = document.querySelectorAll('[data-tab-page]')
    tabPageElements.forEach((tabPageElement) => {
      if (tabPageElement.dataset.tabPage == tabId) {
        tabPageElement.classList.remove('hidden')
      } else {
        tabPageElement.classList.add('hidden')
      }
    })
  }

  activateTab(tabLinkElement, tabLinkElements) {
    tabLinkElements.forEach((tabLinkElement) => {
      tabLinkElement.classList.remove('active')
    })
    tabLinkElement.classList.add('active')
  }
}

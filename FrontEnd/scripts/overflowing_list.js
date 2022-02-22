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

export class SPIOverflowingList extends HTMLElement {
  constructor() {
    super()

    // The list should be the immediate child of the custom element.
    const listElement = this.querySelector(':scope > ul')
    if (!listElement) return

    if (this.getAttribute('aria-expanded') == 'false') {
      // Immediately collapse a potentially overflowing keyword list.
      listElement.style.setProperty('max-height', this.dataset.overflowHeight)

      if (this.isOverflowing(listElement)) {
        // If the collapsing hid any content, add a "show more" that expands it.
        const showMoreElement = document.createElement('a')
        showMoreElement.innerText = this.dataset.overflowMessage
        showMoreElement.href = '#' // Needed to turn the cursor into a hand.
        showMoreElement.classList.add('show_more')
        this.appendChild(showMoreElement)
      }
    }

    // Note: It's important to bind to the event separately to inserting the link
    // element as the event will not be re-bound when navigating back to this page.
    const showMoreElement = this.querySelector('.show_more')
    if (showMoreElement) {
      showMoreElement.addEventListener('click', (event) => {
        this.setAttribute('aria-expanded', 'true')
        listElement.style.removeProperty('max-height')
        showMoreElement.remove()
        event.preventDefault()
      })
    }
  }

  // Adapted from https://stackoverflow.com/a/143889
  isOverflowing(element) {
    var currentOverflow = element.style.overflow
    if (!currentOverflow || currentOverflow === 'visible') element.style.overflow = 'hidden'
    var isOverflowing = element.clientWidth < element.scrollWidth || element.clientHeight < element.scrollHeight
    element.style.overflow = currentOverflow
    return isOverflowing
  }
}

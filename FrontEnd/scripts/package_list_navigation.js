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

import { KeyCodes } from './keycodes.js'

export class SPIPackageListNavigation {
  constructor() {
    document.addEventListener('turbo:load', () => {
      // Is the query field going to be focused on page load? If so, and *only*
      // on first load, position the cursor at the end of the text in the field.
      const queryElement = document.getElementById('query')
      if (queryElement && queryElement.dataset.autofocus) {
        queryElement.selectionEnd = queryElement.value.length
        queryElement.selectionStart = queryElement.value.length
      }
    })

    document.addEventListener('keydown', (event) => {
      // Only add package list navigation if there is a package list to navigate!
      const packageListElement = document.getElementById('package-list')
      if (!packageListElement) return

      // If anything inside a form has focus and this is an enter keypress, continue submitting the form.
      const activeElement = document.activeElement
      const formElement = activeElement.findParentMatching((element) => {
        return element.nodeName.toLowerCase() == 'form'
      })
      if (formElement && event.keyCode === KeyCodes.enter) return

      // The document should never respond to the keys we are overriding.
      if (
        event.keyCode === KeyCodes.enter ||
        event.keyCode === KeyCodes.upArrow ||
        event.keyCode === KeyCodes.downArrow
      ) {
        event.preventDefault()
      }

      // Process the keyboard event.
      switch (event.keyCode) {
        case KeyCodes.downArrow: {
          this.selectNextPackage()
          break
        }
        case KeyCodes.upArrow: {
          this.selectPreviousPackage()
          break
        }
        case KeyCodes.enter: {
          this.navigateToSelectedPackage()
          break
        }
        case KeyCodes.escape: {
          this.selectedPackageIndex = null
          window.scrollToTop()
          break
        }
      }

      // Ensure that the list shows the selected item.
      this.updatePackageListSelection()
    })
  }

  selectNextPackage() {
    const packageListElement = document.getElementById('package-list')
    if (!packageListElement) return

    if (typeof this.selectedPackageIndex !== 'number') {
      // If there is no current selection, start at the top of the list.
      this.selectedPackageIndex = 0
      document.blurFocusedInputElement()
    } else {
      // Otherwise, just move down the list, but never beyond the end!
      this.selectedPackageIndex = Math.min(this.selectedPackageIndex + 1, packageListElement.children.length - 1)

      // When reaching the bottom of the list, scroll to the bottom of the document.
      if (this.selectedPackageIndex == packageListElement.children.length - 1) window.scrollToBottom()
    }
  }

  selectPreviousPackage() {
    const packageListElement = document.getElementById('package-list')
    if (!packageListElement) return

    if (typeof this.selectedPackageIndex !== 'number') {
      // If there is no current selection, do nothing.
      return
    } else if (this.selectedPackageIndex === 0) {
      // Always scroll to the top of the page when navigating to the first item.
      window.scrollToTop()

      // Only navigate to the query field if indicated to by the package list.
      if (packageListElement.dataset.focusQueryField === 'true') {
        const queryElement = document.getElementById('query')
        if (queryElement) queryElement.focus()

        // Also remove any selection when the query field is focused.
        this.selectedPackageIndex = null
      }
    } else {
      // Otherwise, just move up the list.
      this.selectedPackageIndex--
    }
  }

  navigateToSelectedPackage() {
    const packageListElement = document.getElementById('package-list')
    if (!packageListElement) return

    // Grab the selected list item, find the link inside it, and navigate to it.
    const selectedItem = packageListElement.children[this.selectedPackageIndex]
    if (!selectedItem) return
    const linkElement = selectedItem.querySelector('a')
    if (!linkElement) return
    linkElement.click()
  }

  updatePackageListSelection() {
    const packageListElement = document.getElementById('package-list')
    if (!packageListElement) return

    Array.from(packageListElement.children).forEach((listItem, index) => {
      if (index == this.selectedPackageIndex) {
        // Add the selected class to the selected element.
        listItem.classList.add('selected')

        // Ensure that the element is visible
        listItem.scrollIntoView({ block: 'nearest' })
      } else {
        // Remove the selected class from *every* other item.
        listItem.classList.remove('selected')
      }
    })
  }
}

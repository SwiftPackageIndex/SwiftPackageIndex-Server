import { SessionKey } from './session_serialization.js'
import { KeyCodes } from './keycodes.js'

export class SPISearchKeyboardNavigation {
  constructor() {
    this.resetSelectedResult()

    document.addEventListener('DOMContentLoaded', () => {
      this.installQueryFieldEventHandlers()
    })
  }

  installQueryFieldEventHandlers() {
    const queryFieldElement = document.getElementById('query')
    if (!queryFieldElement) { return }

    queryFieldElement.addEventListener('keydown', (event) => {
      // The query field should never respond to the keys we are overriding.
      if (event.keyCode == KeyCodes.enter ||
          event.keyCode == KeyCodes.upArrow ||
          event.keyCode == KeyCodes.downArrow) {
        event.preventDefault()
      }

      this.processKeyDown(event.keyCode)
    })
  }

  processKeyDown(keyCode) {
    const resultsElement = document.getElementById('results')
    if (!resultsElement) { return }
    const resultsListElement = resultsElement.querySelector('ul')
    if (!resultsListElement) { return }
    const queryFieldElement = document.getElementById('query')
    if (!queryFieldElement) { return }
    if (queryFieldElement.value.length <= 0) { return }

    const searchResults = sessionStorage.getDeserializedItem(SessionKey.searchResults)

    switch (keyCode) {
      case KeyCodes.downArrow: {
        this.selectNextResult(searchResults.results)
        break
      }
      case KeyCodes.upArrow: {
        this.selectPreviousResult(searchResults.results)
        this.renderSelectedItem(resultsElement, resultsListElement, searchResults.results)
        break
      }
      case KeyCodes.enter: {
        // Grab the selected list item, find the link inside it, and navigate to it.
        const selectedItemElement = resultsListElement.children[this.selectedResultIndex]
        if (!selectedItemElement) { break }
        const linkElement = selectedItemElement.querySelector('a')
        if (!linkElement) { break }
        linkElement.click()
        break
      }
    }

    // Always ensure that the list is rendering its selection correctly.
    this.renderSelectedItem(resultsElement, resultsListElement, searchResults.results)
  }

  selectNextResult(results) {
    if (typeof(this.selectedResultIndex) !== 'number') {
      // If there is no current selection, start at the top of the list.
      this.selectedResultIndex = 0
    } else {
      // Otherwise, just move down the list, but never beyond the end!
      this.selectedResultIndex = Math.min(this.selectedResultIndex + 1, results.length - 1)
    }
  }

  selectPreviousResult(results) {
    if (typeof(this.selectedResultIndex) !== 'number') {
      // If there is no current selection, start at the bottom of the list.
      this.selectedResultIndex = results.length - 1
    } else {
      // Otherwise, just move up the list, but never beyond the start!
      this.selectedResultIndex = Math.max(this.selectedResultIndex - 1, 0)
    }
  }

  resetSelectedResult() {
    this.selectedResultIndex = null
  }

  renderSelectedItem(resultsElement, resultsListElement, results) {
    Array.from(resultsListElement.children).forEach((listItemElement, index) => {
      if (index == this.selectedResultIndex) {
        // Add the selected class to the selected element.
        listItemElement.classList.add('selected')
        if (this.selectedResultIndex == results.length - 1) {
          // Scroll all the way to the bottom, just in case the "More results are available" text is showing.
          resultsElement.scrollTop = resultsElement.scrollHeight
        } else {
          // Ensure that the element is visible, but don't center it in the div. Just move the minimum amount necessary.
          listItemElement.scrollIntoView({ block: 'nearest' })
        }
      } else {
        // Remove the selected class from *every* other item.
        listItemElement.classList.remove('selected')
      }
    })
  }
}

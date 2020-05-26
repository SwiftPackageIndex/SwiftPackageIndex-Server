import { SessionKey } from './session_serialization.js'
import { OpenExternalLinksInBlankTarget } from './links.js'
import { SPISearchCore } from './search_core.js'

new OpenExternalLinksInBlankTarget()
new SPISearchCore()

document.addEventListener('DOMContentLoaded', function() {
  const queryFieldElement = document.getElementById('results')
  if (!queryFieldElement) { return }

  queryFieldElement.addEventListener('keydown', function(event) {
    // The query field should *never* respond to the enter key.
    if (event.keyCode == 13) { event.preventDefault() }

    const resultsElement = document.getElementById('results')
    if (!resultsElement) { return }
    const resultsListElement = resultsElement.querySelector('ul')
    if (!resultsListElement) { return }

    const queryFieldElement = event.target
    if (queryFieldElement.value.length <= 0) { return }

    const searchResults = sessionStorage.getDeserializedItem(SessionKey.searchResults)

    switch (event.keyCode) {
      case 13: { // Enter
        const selectedItemElement = resultsListElement.children[window.searchResultSelectedIndex]
        const linkElement = selectedItemElement.querySelector('a')
        linkElement.click()
        break
      }
      case 38: { // Up arrow
        if (typeof(window.searchResultSelectedIndex) !== 'number') {
          window.searchResultSelectedIndex = searchResults.results.length - 1
        } else {
          window.searchResultSelectedIndex = Math.max(window.searchResultSelectedIndex - 1, 0)
        }
        break
      }
      case 40: { // Down arrow
        if (typeof(window.searchResultSelectedIndex) !== 'number') {
          window.searchResultSelectedIndex = 0
        } else {
          window.searchResultSelectedIndex = Math.min(window.searchResultSelectedIndex + 1, searchResults.results.length - 1)
        }
        break
      }
    }

    Array.from(resultsListElement.children).forEach(function(listItemElement, index) {
      if (index == window.searchResultSelectedIndex) {
        listItemElement.classList.add('selected')
        if (window.searchResultSelectedIndex == searchResults.results.length - 1) {
          // Scroll all the way to the bottom, just in case the "More results are available" text is showing.
          resultsElement.scrollTop = resultsElement.scrollHeight
        } else {
          // Ensure that the element is visible, but don't center it in the div. Just move the minimum amount necessary.
          listItemElement.scrollIntoViewIfNeeded(false)
        }
      } else { listItemElement.classList.remove('selected') }
    })
  })
})

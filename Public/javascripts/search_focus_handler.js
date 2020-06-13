export class SPISearchFocusHandler {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      this.installDocumentEventHandlers()
      this.installQueryFieldEventHandlers()
    })
  }

  installDocumentEventHandlers() {
    // This needs to be a `mousedown`, not a `click` as it needs to fire *before* `blur` where `click` fires after it.
    document.addEventListener('mousedown', () => {
      const queryFieldElement = document.getElementById('query')
      if (!queryFieldElement) { return }
      const resultsElement = document.getElementById('results')
      if (!resultsElement) { return }

      // Navigate through the DOM to determine if the mouse down is in a child of the `#results` element.
      var target = event.target
      do {
        if (target === resultsElement) {
          queryFieldElement.setAttribute('data-prevent-blur', true)
        }
      } while ((target = target.parentElement))
    })
  }

  installQueryFieldEventHandlers() {
    const queryFieldElement = document.getElementById('query')
    if (!queryFieldElement) { return }

    // When focus is given to the query field, show the results if there is a query.
    queryFieldElement.addEventListener('focus', (event) => {
      window.spiSearchCore.performSearch(event.target)
    })

    // When focus is lost, always hide the results div.
    queryFieldElement.addEventListener('blur', () => {
      const queryFieldElement = document.getElementById('query')
      if (!queryFieldElement) { return }

      if (queryFieldElement.getAttribute('data-prevent-blur')) {
        queryFieldElement.removeAttribute('data-prevent-blur')
        return false // Prevent the blur from blurring.
      } else {
        const resultsElement = window.spiSearchCore.hiddenSearchResultsElement()
        window.spiSearchCore.replaceResultsDivWith(resultsElement)
      }
    })
  }
}

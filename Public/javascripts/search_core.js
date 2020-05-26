import debounce from 'lodash/debounce'
import axios from 'axios'

import { SessionKey } from './session_serialization.js'
import { setElementHiddenById } from './dom_helpers.js'

export class SPISearchCore {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      this.installWindowEventHandlers()
      this.installQueryFieldEventHandlers()
    })
  }

  installWindowEventHandlers() {
    // The pageshow event happens *after* load. This is the first opportunity to get the page
    // in a state where autocompleted fields have been populated. This is necessary because
    // the browser uses autocompletion to restore any search text in the query field.
    window.addEventListener('pageshow', () => {
      const queryFieldElement = document.getElementById('query')
      if (!queryFieldElement) { return }

      // If there's already a query, the search results may be cached in session storage.
      const searchQuery = queryFieldElement.value.trim()
      if (searchQuery.length > 0) {
        const searchResults = sessionStorage.getDeserializedItem(SessionKey.searchResults)
        if (searchResults) {
          this.clearSearchResults()
          this.displaySearchResults(searchResults)
        }
      } else {
        // Otherwise, just force the results element to be hidden.
        setElementHiddenById('results', true)
      }
    })
  }

  installQueryFieldEventHandlers() {
    const queryFieldElement = document.getElementById('query')
    if (!queryFieldElement) { return }

    // When any input is received by the query field, perform the search.
    queryFieldElement.addEventListener('input', debounce((event) => {
      const queryFieldElement = event.target
      const searchQuery = queryFieldElement.value.trim()
      if (searchQuery.length > 0) {
        this.performSearch(searchQuery)
      } else {
        // With no query, there will be no results.
        setElementHiddenById('results', true)
      }
    }), 300)
  }

  performSearch(searchQuery) {
    const searchUrl = '/api/search?query=' + searchQuery

    // Clear out any existing content. Errors, the loading indicator, or previous results.
    this.clearSearchResults()

    // Cancel any already running search requests.
    if (this.requestCancelFunction) { this.requestCancelFunction() }

    axios.get(searchUrl, {
      cancelToken: new axios.CancelToken((cancelFunction) => {
        this.requestCancelFunction = cancelFunction
      })
    }).then((response) => {
      // Cache the search results in session storage, then display them.
      sessionStorage.setSerializedItem(SessionKey.searchResults, response.data)
      this.displaySearchResults(response.data)

      // Reset the keyboard navigation selected index as these are new results.
      if (window.spiSearchKeyboardNavigation) {
        window.spiSearchKeyboardNavigation.resetSelectedResult()
      }
    }).catch((error) => {
      // Ignore errors as a result of cancellation, but log everything else.
      if (!axios.isCancel(error)) {
        console.error(error)
        this.displayErrorMessage(error)
      }
    })

    // Doesn't matter if there was an error, or valid results, always show the results area.
    setElementHiddenById('results', false)
  }

  clearSearchResults() {
    const resultsElement = document.getElementById('results')
    if (!resultsElement) { return }

    while (resultsElement.lastElementChild) {
      resultsElement.removeChild(resultsElement.lastElementChild)
    }
  }

  displaySearchResults(searchResults) {
    const resultsElement = document.getElementById('results')
    if (!resultsElement) { return }

    // Are there any results?
    const numResults = searchResults.results.length
    if (numResults <= 0) {
      const noResultsElement = document.createElement('p')
      noResultsElement.textContent = 'No Results. Try another search?'
      noResultsElement.classList.add('no_results')
      resultsElement.appendChild(noResultsElement)
    } else {
      // Create an unordered list with the results.
      const resultsListElement = document.createElement('ul')
      searchResults.results.forEach((result) => {
        this.createSearchResultListItemElement(result, resultsListElement)
      })
      resultsElement.appendChild(resultsListElement)

      // Are there more search results available?
      if (searchResults.hasMoreResults) {
        const moreResultsElement = document.createElement('p')
        moreResultsElement.textContent = `More than ${numResults} results match this query. Try a more specific search.`
        moreResultsElement.classList.add('more_results')
        resultsElement.appendChild(moreResultsElement)
      }
    }
  }

  displayErrorMessage(error) {
    const resultsElement = document.getElementById('results')
    if (!resultsElement) { return }

    // Container for the error message.
    const errorContainerElement = document.createElement('div')
    errorContainerElement.classList.add('error')
    resultsElement.appendChild(errorContainerElement)

    // Start with an icon.
    const errorIconElement = document.createElement('i')
    errorIconElement.classList.add('icon')
    errorIconElement.classList.add('warning')
    errorContainerElement.appendChild(errorIconElement)

    // Header, with a quick apology.
    const errorHeaderElement = document.createElement('h4')
    errorHeaderElement.textContent = 'Something went wrong. Sorry!'
    errorContainerElement.appendChild(errorHeaderElement)

    // Then, what actually happened.
    const errorMessageElement = document.createElement('p')
    errorContainerElement.appendChild(errorMessageElement)

    // Finally, what was the error?
    if (error.response) {
      errorMessageElement.textContent = error.response.status + ' – ' + error.response.statusText

      // Is there any extra information in the "reason" that might be useful?
      if (!!error.response.data && !!error.response.data.reason && error.response.data.reason != error.response.statusText) {
        errorMessageElement.textContent +=  ' – ' + error.response.data.reason
      }
    } else {
      errorMessageElement.textContent = 'Unexpected Error.'
    }
  }

  createSearchResultListItemElement(result, containerElement) {
    const resultListItemElement = document.createElement('li')

    // A link surrounds the whole content of the list item.
    const linkElement = document.createElement('a')
    linkElement.href = '/packages/' + result.id
    resultListItemElement.appendChild(linkElement)

    // Name and repository identifier need to be grouped to be split.
    const nameAndRepositoryContainer = document.createElement('div')
    linkElement.appendChild(nameAndRepositoryContainer)

    // Name.
    const nameElement = document.createElement('h4')
    nameElement.textContent = result.name
    nameAndRepositoryContainer.appendChild(nameElement)

    // Repository identifier.
    const repositoryElement = document.createElement('small')
    repositoryElement.textContent = result.owner + '/' + result.package_name
    nameAndRepositoryContainer.appendChild(repositoryElement)

    // Summary.
    const summaryElement = document.createElement('p')
    summaryElement.textContent = result.summary
    linkElement.appendChild(summaryElement)

    containerElement.appendChild(resultListItemElement)
  }

}

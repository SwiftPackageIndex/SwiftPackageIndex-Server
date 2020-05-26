import debounce from 'lodash/debounce'
import axios from 'axios'

import { SessionKey } from './session_serialization.js'

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

      // If there's already a query, the search results should be cached in session storage.
      const searchQuery = queryFieldElement.value.trim()
      const searchResults = sessionStorage.getDeserializedItem(SessionKey.searchResults)
      if (searchQuery.length > 0 && searchResults) {
        // Update the search results div to display the cached results.
        this.replaceResultsDivWith(this.searchResultsElement(searchResults))
      } else {
        // Update the search results div with a hidden results div.
        this.replaceResultsDivWith(this.hiddenSearchResultsElement())
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
        this.replaceResultsDivWith(this.hiddenSearchResultsElement())
      }
    }), 300)
  }

  performSearch(searchQuery) {
    const searchUrl = '/api/search?query=' + searchQuery

    // Cancel any already running search requests.
    if (this.requestCancelFunction) { this.requestCancelFunction() }

    axios.get(searchUrl, {
      cancelToken: new axios.CancelToken((cancelFunction) => {
        this.requestCancelFunction = cancelFunction
      })
    }).then((response) => {
      // Cache the search results in session storage in case they need to be re-displayed.
      const searchResults = response.data
      sessionStorage.setSerializedItem(SessionKey.searchResults, searchResults)

      // Update the search results div to display the new results.
      this.replaceResultsDivWith(this.searchResultsElement(searchResults))

      // Reset the keyboard navigation selected index as these are new results.
      if (window.spiSearchKeyboardNavigation) {
        window.spiSearchKeyboardNavigation.resetSelectedResult()
      }
    }).catch((error) => {
      // Ignore errors as a result of cancellation, but log everything else.
      if (!axios.isCancel(error)) {
        console.error(error)

        // Update the search results div to display an error message.
        this.replaceResultsDivWith(this.searchResultsErrorElement(error))
      }
    })
  }


  // -- Search result replacement ---------------------------------------------

  replaceResultsDivWith(element) {
    const resultsElement = document.getElementById('results')
    if (resultsElement) { resultsElement.replaceWith(element) }
  }

  // -- Methods that return a new results div ---------------------------------

  hiddenSearchResultsElement() {
    // Create a new results div, and hide it.
    const resultsElement = document.createElement('div')
    resultsElement.id = 'results'
    resultsElement.hidden = true
    return resultsElement
  }

  searchResultsElement(searchResults) {
    // Create a new results div with either a message saying no results
    // could be found, or a list of search results.
    const resultsElement = document.createElement('div')
    resultsElement.id = 'results'

    // Are there any results?
    const numResults = searchResults.results.length
    if (numResults <= 0) {
      resultsElement.appendChild(this.searchNoResultsElement())
    } else {
      // Create an unordered list to hold the results.
      const resultsListElement = document.createElement('ul')
      resultsElement.appendChild(resultsListElement)

      // Populate it with result elements for every result.
      searchResults.results.forEach((result) => {
        resultsListElement.appendChild(this.searchResultElement(result))
      })

      // Are there more search results available?
      if (searchResults.hasMoreResults) {
        resultsElement.appendChild(this.moreResultsElement(numResults))
      }
    }

    return resultsElement
  }

  searchResultsErrorElement(error) {
    // Create a new results div with an error message.
    const resultsElement = document.createElement('div')
    resultsElement.id = 'results'
    resultsElement.classList.add('error')

    // Start with an icon.
    const errorIconElement = document.createElement('i')
    errorIconElement.classList.add('icon')
    errorIconElement.classList.add('warning')
    resultsElement.appendChild(errorIconElement)

    // Header, with a quick apology.
    const errorHeaderElement = document.createElement('h4')
    errorHeaderElement.textContent = 'Something went wrong. Sorry!'
    resultsElement.appendChild(errorHeaderElement)

    // Then, what actually happened.
    const errorMessageElement = document.createElement('p')
    resultsElement.appendChild(errorMessageElement)

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

    return resultsElement
  }

  // -- Helper methods to aid in the production of the search results div -----

  searchNoResultsElement() {
    const noResultsElement = document.createElement('p')
    noResultsElement.textContent = 'No Results. Try another search?'
    noResultsElement.classList.add('no_results')
    return noResultsElement
  }

  moreResultsElement(numResults) {
    const moreResultsElement = document.createElement('p')
    moreResultsElement.textContent = `More than ${numResults} results match this query. Try a more specific search.`
    moreResultsElement.classList.add('more_results')
    return moreResultsElement
  }

  searchResultElement(result) {
    const searchResultElement = document.createElement('li')

    // A link surrounds the whole content of the list item.
    const linkElement = document.createElement('a')
    linkElement.href = '/packages/' + result.id
    searchResultElement.appendChild(linkElement)

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

    return searchResultElement
  }
}

// Constants for session key storage.
const SessionKey = {
  searchResults: 'searchResults'
}

document.addEventListener('DOMContentLoaded', function(event) {
  // Force external links to open with a _blank target.
  document.addEventListener('click', function(event) {
    var target = event.target
    do {
      if (target.nodeName.toLowerCase() == 'a' && target.hostname != window.location.hostname) {
        target.setAttribute('target', '_blank')
      }
    } while (target = target.parentElement)
  })

  // If there is a search element, configure the search callbacks.
  const queryFieldElement = document.getElementById('query')
  if (!!queryFieldElement) {
    // When user input is entered into the query field, perform the search.
    document.addEventListener('input', function(event) {
      const searchQuery = queryFieldElement.value.trim()
      if (searchQuery.length > 0) {
        performSearch(searchQuery)
      } else {
        // With no query, there will be no results.
        setElementHiddenById('results', true)
      }
    })
  }
})

window.addEventListener('pageshow', function(event) {
  // If there is a search element, configure the search callbacks.
  const queryFieldElement = document.getElementById('query')
  if (!!queryFieldElement) {
    // If there's already a query in the input field, display results from session storage.
    const searchQuery = queryFieldElement.value.trim()
    if (searchQuery.length > 0) {
      const searchResultsJSON = sessionStorage.getItem(SessionKey.searchResults)
      if (!!searchResultsJSON) {
        clearSearchResults()
        displaySearchResults(JSON.parse(searchResultsJSON))
      }
    } else {
      // Otherwise, just force the results element to be hidden.
      setElementHiddenById('results', true)
    }
  }
})

window.performSearch = _.debounce(function(searchQuery) {
  const searchUrl = '/api/search?query=' + searchQuery

  // Clear out any existing content. Errors, the loading indicator, or previous results.
  clearSearchResults()

  axios.get(searchUrl).then(function(response) {
    // Cache the search results into session storage, then show them.
    sessionStorage.setItem(SessionKey.searchResults, JSON.stringify(response.data))
    displaySearchResults(response.data)
  }).catch(function(error) {
    console.error(error) // At the very least, always log to the console.
    displayErrorMessage(error)
  })

  // Doesn't matter if there was an error, or valid results, always show the results area.
  setElementHiddenById('results', false)
}, 200)

window.clearSearchResults = function() {
  const resultsElement = document.getElementById('results')
  if (!resultsElement) { return }

  while (resultsElement.lastElementChild) {
    resultsElement.removeChild(resultsElement.lastElementChild)
  }
}

window.displaySearchResults = function(searchResults) {
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
    searchResults.results.forEach((result, index) => {
      createSearchResultListItemElement(result, resultsListElement)
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

window.displayErrorMessage = function(error) {
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
  if (!!error.response) {
    errorMessageElement.textContent = error.response.status + ' – ' + error.response.statusText

    // Is there any extra information in the "reason" that might be useful?
    if (!!error.response.data && !!error.response.data.reason && error.response.data.reason != error.response.statusText) {
      errorMessageElement.textContent +=  ' – ' + error.response.data.reason
    }
  } else {
    errorMessageElement.textContent = 'Unexpected Error.'
  }
}

// Helpers

function setElementHiddenById(id, hidden) {
  const element = document.getElementById(id)
  if (!!element) { element.hidden = hidden }
}

function createSearchResultListItemElement(result, containerElement) {
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

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

  // If there's a results element, its initial state should be hidden.
  const resultsElement = document.getElementById('results')
  if (resultsElement) { resultsElement.hidden = true }

  // If there is a search element, configure the search callbacks.
  const queryFieldElement = document.getElementById('query')
  if (queryFieldElement) {
    document.addEventListener('input', function(event) {
      performSearch(queryFieldElement.value)
    })
  }
})

window.performSearch = _.debounce(function(searchQuery) {
  const searchUrl = '/api/search?query=' + searchQuery

  axios.get(searchUrl).then(function(response) {
    displaySearchResults(response.data)
  }).catch(function(error) {
    console.error(error) // TODO: Display the error.
  })
}, 200)

window.clearSearchResults = function() {
  const resultsElement = document.getElementById('results')
  if (resultsElement == null) { return }

  while (resultsElement.lastElementChild) {
    resultsElement.removeChild(resultsElement.lastElementChild)
  }
}

window.displaySearchResults = function(searchResults) {
  const resultsElement = document.getElementById('results')
  if (resultsElement == null) { return }

  // Clear out any existing content. Either the loading indicator, or previous results.
  clearSearchResults()

  // Are there any results?
  if (searchResults.length <= 0) {
    const noResultsElement = document.createElement('p')
    noResultsElement.textContent = 'No Results.'
    resultsElement.appendChild(noResultsElement)
  } else {
    // Create an unordered list with the results.
    const resultsListElement = document.createElement('ul')
    searchResults.forEach((result, index) => {
      const resultsItemElement = document.createElement('li')

      // Name.
      const resultNameElement = document.createElement('h4')
      resultNameElement.textContent = result.name
      resultsItemElement.appendChild(resultNameElement)

      // Repository identifier.
      const resultRepositoryElement = document.createElement('small')
      resultRepositoryElement.textContent = result.owner + '/' + result.package_name
      resultsItemElement.appendChild(resultRepositoryElement)

      // Summary.
      const resultSummaryElement = document.createElement('p')
      resultSummaryElement.textContent = result.summary
      resultsItemElement.appendChild(resultSummaryElement)

      resultsListElement.appendChild(resultsItemElement)
    })
    resultsElement.appendChild(resultsListElement)
  }

  // At the end of this process, the element should *always* be visible.
  resultsElement.hidden = false
}

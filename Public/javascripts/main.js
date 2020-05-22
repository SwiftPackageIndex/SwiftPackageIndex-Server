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
      const searchQuery = queryFieldElement.value.trim()
      if (searchQuery.length > 0) {
        performSearch(searchQuery)
      } else {
        const resultsElement = document.getElementById('results')
        if (resultsElement) { resultsElement.hidden = true }
      }
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
  if (searchResults.results.length <= 0) {
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
  }

  // At the end of this process, the element should *always* be visible.
  resultsElement.hidden = false
}

// Helpers

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

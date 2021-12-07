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

export class SPISearchFilterSuggestions {
  static suggestions = [
    {
      filter: 'stars:>500',
      description: 'Filter on packages with more than 500 stars.',
    },
    {
      filter: 'last_activity:>2021-01-01',
      description: 'Filter on packages with a commit or a closed/merged pull request or issue in the last 30 days.',
    },
    {
      filter: 'last_commit:>2021-01-01',
      description: 'Filter on packages with a commit in the last 30 days.',
    },
  ]

  constructor() {
    document.addEventListener('turbo:before-cache', () => {
      const searchSectionElement = document.querySelector('[data-filter-suggestions]')
      if (!searchSectionElement) return

      // Remove any search filter suggestions before the page is cached so they can be
      // re-inserted correctly. Otherwise, the handler events all get removed.
      const filterSuggestionsElement = searchSectionElement.querySelector('.filter_suggestions')
      if (filterSuggestionsElement) filterSuggestionsElement.remove()
    })

    document.addEventListener('turbo:load', () => {
      const searchSectionElement = document.querySelector('[data-filter-suggestions]')
      if (!searchSectionElement) return
      const searchFieldElement = searchSectionElement.querySelector('form input[type=search]')
      if (!searchFieldElement) return

      // Add the search suggestions below the search field.
      const filterSuggestionsElement = document.createElement('div')
      filterSuggestionsElement.classList.add('filter_suggestions')
      filterSuggestionsElement.innerHTML =
        'Add filters for better results (<a href="/faq#search-filters">Learn more</a>). For example: '
      searchSectionElement.appendChild(filterSuggestionsElement)

      SPISearchFilterSuggestions.suggestions.forEach((suggestion) => {
        const linkElement = document.createElement('a')
        linkElement.textContent = suggestion.filter
        linkElement.title = suggestion.description
        linkElement.dataset.filter = suggestion.filter
        filterSuggestionsElement.appendChild(linkElement)

        // Top and tail with quotes.
        // Note: The element *must* be inserted into the DOM for this to work.
        linkElement.insertAdjacentHTML('beforebegin', '&ldquo;')
        linkElement.insertAdjacentHTML('afterend', '&rdquo; ')

        linkElement.addEventListener('click', (event) => {
          event.preventDefault()

          // Grab the filter and parse it out to get the lengths of each side.
          const separator = ':'
          const filter = linkElement.dataset.filter
          const filterElements = filter.split(separator)
          const valueLength = filterElements.pop().length
          const fieldLength = filterElements.pop().length
          const whitespace = ' ' // To separate the suggested filter from the existing search term

          // Append the filter to the existing search term.
          var currentSearch = searchFieldElement.value.trimEnd()
          searchFieldElement.value = currentSearch + whitespace + filter

          // Finally, focus the value portion of the suggested filter.
          const selectionStart = currentSearch.length + fieldLength + separator.length + whitespace.length
          const selectionEnd = selectionStart + valueLength
          searchFieldElement.focus()
          searchFieldElement.setSelectionRange(selectionStart, selectionEnd, 'forward')
        })
      })
    })
  }
}

// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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
            text: 'number of stars',
            filter: 'stars:>500',
            description: 'Filter to packages having more than 500 stars.',
        },
        {
            text: 'last maintenance activity',
            filter: `last_activity:>${this.formattedFilterDate()}`,
            description:
                'Filter to packages having a commit or a closed/merged pull request or issue in the last three months.',
        },
        {
            text: 'compatible platforms',
            filter: `platform:ios,linux`,
            description: 'Filter to packages compatible with both iOS and Linux.',
        },
        {
            text: 'product types',
            filter: `product:plugin`,
            description: 'Filter to packages that export a plugin product.',
        },
    ]

    constructor() {
        document.addEventListener('turbo:before-cache', () => {
            // Remove any search filter suggestions before the page is cached so they can be
            // re-inserted correctly. Otherwise, the handler events all get removed.
            const suggestionsSentenceElement = document.querySelector('.filter-suggestions .suggestions')
            if (suggestionsSentenceElement) suggestionsSentenceElement.remove()
        })

        document.addEventListener('turbo:load', () => {
            const filterSuggestionsElement = document.querySelector('.filter-suggestions')
            if (!filterSuggestionsElement) return
            const searchFieldElement = document.querySelector('form input[type=search]')
            if (!searchFieldElement) return

            const suggestionElements = SPISearchFilterSuggestions.suggestions.map((suggestion) => {
                const linkElement = document.createElement('a')
                linkElement.textContent = suggestion.text
                linkElement.title = suggestion.description
                linkElement.dataset.filter = suggestion.filter
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
                    searchFieldElement.focus() // Focus must be set before the selection otherwise the text field does not scroll to end.
                    searchFieldElement.setSelectionRange(selectionStart, selectionEnd, 'forward')
                })
                return linkElement
            })

            // Put all suggestions in an identifiable element so they can be removed in `before-cache`.
            const suggestionsSentenceElement = document.createElement('span')
            suggestionsSentenceElement.classList.add('suggestions')
            filterSuggestionsElement.append(suggestionsSentenceElement)

            // Construct the sentence containing all suggestions.
            const lastSuggestionElement = suggestionElements.pop()
            suggestionsSentenceElement.appendChild(document.createTextNode('Try filtering by '))
            suggestionElements.forEach((suggestionElement) => {
                suggestionsSentenceElement.appendChild(suggestionElement)
                suggestionsSentenceElement.appendChild(document.createTextNode(', '))
            })
            suggestionsSentenceElement.appendChild(document.createTextNode('or '))
            suggestionsSentenceElement.appendChild(lastSuggestionElement)
            suggestionsSentenceElement.appendChild(document.createTextNode('. '))

            // Move the "Learn more" link to the end of the sentence.
            const learnMoreElement = filterSuggestionsElement.querySelector('.learn_more')
            if (learnMoreElement) {
                learnMoreElement.remove()
                filterSuggestionsElement.insertAdjacentElement('beforeend', learnMoreElement)
            }
        })
    }

    static formattedFilterDate() {
        var ninetyDaysAgo = new Date()
        ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90)

        const year = ninetyDaysAgo.getFullYear()
        const month = ninetyDaysAgo.getMonth() + 1 // Yes, JavaScript returns months as zero based.
        const day = ninetyDaysAgo.getDate() // ... but not the day of the month. That's one based.

        return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
    }
}

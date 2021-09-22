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

export class SPIShowMoreKeywords {
  constructor() {
    document.addEventListener('turbo:load', () => {
      // Immediately collapse the overflowing keyword list.
      const keywordsListElement = document.querySelector('article.details ul.keywords')
      keywordsListElement.classList.add('collapsed')

      // If the collapsing hid any content, add a "show more" that expands it.
      if (this.isOverflowing(keywordsListElement)) {
        const totalKeywords = keywordsListElement.children.length

        // Either
        const showMoreElement = document.createElement('a')
        showMoreElement.innerText = `Show all ${totalKeywords} tags`
        showMoreElement.href = '#'

        // Or
        // const showMoreElement = document.createElement('button')
        // showMoreElement.innerText = `Show all ${totalKeywords} tags`

        showMoreElement.addEventListener('click', (event) => {
          keywordsListElement.classList.remove('collapsed')
          showMoreElement.remove()
          event.preventDefault()
        })

        // Put the link in a container so it may be justified. (Remove if unneeded before merging)
        const buttonContainerElement = document.createElement('div')
        buttonContainerElement.classList.add('show_more')
        buttonContainerElement.appendChild(showMoreElement)

        const keywordsListParentElement = keywordsListElement.parentElement
        keywordsListParentElement.appendChild(buttonContainerElement)
      }
    })
  }

  // Adapted from https://stackoverflow.com/a/143889
  isOverflowing(element) {
    var currentOverflow = element.style.overflow
    if (!currentOverflow || currentOverflow === 'visible') element.style.overflow = 'hidden'
    var isOverflowing = element.clientWidth < element.scrollWidth || element.clientHeight < element.scrollHeight
    element.style.overflow = currentOverflow
    return isOverflowing
  }
}

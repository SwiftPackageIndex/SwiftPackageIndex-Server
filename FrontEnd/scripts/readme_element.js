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

export class SPIReadmeElement extends HTMLElement {
  constructor() {
    super()

    const linkElements = this.querySelectorAll('a')
    linkElements.forEach((linkElement) => {
      // Remove turbo from *all* links inside the README.
      linkElement.setAttribute('data-turbo', 'false')

      const linkTarget = linkElement.getAttribute('href')
      if (linkTarget.charAt(0) === '#') {
        // Fix up anchor URLs by faking the navigation.
        linkElement.addEventListener('click', (event) => {
          const targetAnchor = `user-content-${linkTarget.substring(1)}`
          const destinationElement = document.getElementById(targetAnchor)
          if (destinationElement) destinationElement.scrollIntoView()
          event.preventDefault()
        })
      }
    })
  }
}

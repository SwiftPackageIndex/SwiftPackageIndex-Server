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

import { Controller } from '@hotwired/stimulus'

export class ScrollPositionRestorationController extends Controller {
  static values = {
    cacheKey: String,
  }

  connect() {
    // When an element using this controller loads, restore the height from the cache
    // if it has been previously stored. The cache uses the URLs path as a key so that
    // heights are only restored on matching pages. All storage is session-only and
    // won't persist across re-launches of the browser.
    const heightCache = this.heightCache
    if (!heightCache) return

    const readmeHeight = heightCache[window.location.pathname]
    if (!readmeHeight) return

    this.element.style.setProperty('height', readmeHeight)
  }

  persistHeightToCache() {
    // It's important to store the height as a string so it can be compared to `undefined` above.
    const heightCache = this.heightCache || {}
    heightCache[window.location.pathname] = `${this.element.clientHeight}px`
    this.heightCache = heightCache

    // Once the height has been auto-calculated, the height property is no longer needed.
    this.element.style.removeProperty('height')
  }

  get heightCache() {
    const json = window.sessionStorage.getItem(this.cacheKeyValue)
    if (typeof json === 'string' && json.length > 0) {
      return JSON.parse(json)
    } else {
      return undefined
    }
  }

  set heightCache(hash) {
    if (hash) {
      window.sessionStorage.setItem(this.cacheKeyValue, JSON.stringify(hash))
    } else {
      window.sessionStorage.removeItem(this.cacheKeyValue)
    }
  }
}

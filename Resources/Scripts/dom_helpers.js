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

HTMLElement.prototype.findParentMatching = function (matches) {
  // Walk up the DOM and see if any of the parent elements match using the provided closure.
  let element = this
  do {
    if (matches(element)) return element
  } while ((element = element.parentElement))
  return null
}

HTMLDocument.prototype.blurFocusedInputElement = function () {
  const activeElement = this.activeElement
  if (activeElement.nodeName.toLowerCase() === 'input') activeElement.blur()
}

Window.prototype.scrollToTop = function () {
  window.scrollTo(0, 0)
}

Window.prototype.scrollToBottom = function () {
  window.scrollTo(0, this.document.body.scrollHeight)
}

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

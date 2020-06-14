HTMLElement.prototype.findParentMatching = function(matches) {
  // Walk up the DOM and see if any of the parent elements match using the provided closure.
  let element = this
  do { if (matches(element)) { return element } } while ((element = element.parentElement))
  return null
}

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
})

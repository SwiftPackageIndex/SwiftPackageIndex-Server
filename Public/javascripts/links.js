export default class OpenExternalLinksInBlankTarget {
  constructor() {
    document.addEventListener('DOMContentLoaded', function() {
      document.addEventListener('click', function(event) {
        var target = event.target
        do {
          // Force a blank target for anything that's a link, with a destination that's on a different host.
          if (target.nodeName.toLowerCase() == 'a' && target.hostname != window.location.hostname) {
            target.setAttribute('target', '_blank')
          }
        // Move up the DOM, in case the click was on a nested element but the link is further up in the hierarchy.
        // If there's no links in the hierarchy from here up, this will eventually hit the document root and finish.
        } while ((target = target.parentElement))
      })
    })
  }
}

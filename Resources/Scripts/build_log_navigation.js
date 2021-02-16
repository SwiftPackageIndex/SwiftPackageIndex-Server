export class SPIBuildLogNavigation {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      const buildLogElement = document.getElementById('build_log')
      if (!buildLogElement) {
        return
      }

      // Scroll to the bottom of the log.
      buildLogElement.scrollTop = buildLogElement.scrollHeight
    })
  }
}

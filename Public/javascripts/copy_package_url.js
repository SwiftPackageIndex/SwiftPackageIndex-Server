import delay from 'lodash/delay'

export class SPICopyPackageURL {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      this.createCopyPackageButton()
    })
  }

  createCopyPackageButton() {
    const packageURLElement = document.getElementById('package_url')
    if (!packageURLElement) { return }

    // Given that the button will only work with JavaScript available, we should use JavaScript to create it!
    const copyButtonElement = document.createElement('button')
    copyButtonElement.textContent = 'Copy'
    packageURLElement.parentNode.appendChild(copyButtonElement)

    // Copy the URL on click/tap.
    copyButtonElement.addEventListener('click', () => {
      navigator.clipboard.writeText(packageURLElement.href).then(() => {
        copyButtonElement.textContent = 'Copied!'

        // Change the text back after a short delay.
        delay(() => { copyButtonElement.textContent = 'Copy' }, 1000)
      })
    })
  }
}


// TODO: factor out
export class SPICopySwiftVersionBadge {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      this.createCopySwiftVersionBadgeButton()
    })
  }

  createCopySwiftVersionBadgeButton() {
    const element = document.getElementById('swift_version_badge')
    if (!element) { return }

    // Given that the button will only work with JavaScript available, we should use JavaScript to create it!
    const copyButtonElement = document.createElement('button')
    copyButtonElement.textContent = 'Copy badge'
    element.parentNode.appendChild(copyButtonElement)

    // Copy the URL on click/tap.
    copyButtonElement.addEventListener('click', () => {
      navigator.clipboard.writeText(element.textContent).then(() => {
        copyButtonElement.textContent = 'Copied!'

        // Change the text back after a short delay.
        delay(() => { copyButtonElement.textContent = 'Copy badge' }, 1000)
      })
    })
  }
}


// TODO: factor out
export class SPICopyPlatformBadge {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      this.createCopyPlatformBadgeButton()
    })
  }

  createCopyPlatformBadgeButton() {
    const element = document.getElementById('platform_badge')
    if (!element) { return }

    // Given that the button will only work with JavaScript available, we should use JavaScript to create it!
    const copyButtonElement = document.createElement('button')
    copyButtonElement.textContent = 'Copy badge'
    element.parentNode.appendChild(copyButtonElement)

    // Copy the URL on click/tap.
    copyButtonElement.addEventListener('click', () => {
      navigator.clipboard.writeText(element.textContent).then(() => {
        copyButtonElement.textContent = 'Copied!'

        // Change the text back after a short delay.
        delay(() => { copyButtonElement.textContent = 'Copy badge' }, 1000)
      })
    })
  }
}

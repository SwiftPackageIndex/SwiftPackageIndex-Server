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

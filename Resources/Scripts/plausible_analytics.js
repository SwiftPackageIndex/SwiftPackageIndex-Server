export function measurePlausibleEvent(event) {
  if (typeof plausible === 'function') {
    // eslint-disable-next-line no-undef
    plausible(event)
  }
}

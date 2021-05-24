export function measurePlausibleEvent(event, options = {}) {
  if (typeof plausible === 'function') {
    // eslint-disable-next-line no-undef
    plausible(event, options)
  }
}

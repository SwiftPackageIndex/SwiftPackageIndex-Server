export function measurePlausibleEvent(event) {
  // eslint-disable-next-line no-undef
  if (typeof plausible === 'function') {
    plausible(event)
  }
}

export function setElementHiddenById(id, hidden) {
  const element = document.getElementById(id)
  if (element) { element.hidden = hidden }
}

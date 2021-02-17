export const SessionKey = {
  searchResults: 'com.swiftpackageindex.searchResults'
}

Storage.prototype.getDeserializedItem = function(key) {
  const value = this.getItem(key)
  return (value) ? JSON.parse(value) : null
}

Storage.prototype.setSerializedItem = function (key, value) {
  this.setItem(key, JSON.stringify(value))
}

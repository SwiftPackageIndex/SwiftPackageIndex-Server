
// Common types used across view models


struct Link: Equatable {
    var label: String
    var url: String
}

struct DatedLink: Equatable {
    var date: String
    var link: Link
}

import Foundation


// LosslessStringConvertible conformance is required by @Option command line argument conversion
extension Date: LosslessStringConvertible {
    private static let ymd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    public init?(yyyyMMdd: String) {
        guard let date = Self.ymd.date(from: yyyyMMdd) else { return nil }
        self = date
    }

    public init?(_ string: String) {
        self.init(yyyyMMdd: string)
    }
}

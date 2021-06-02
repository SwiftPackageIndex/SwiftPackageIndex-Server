import Foundation


// LosslessStringConvertible conformance is required by @Option command line argument conversion
extension Date: LosslessStringConvertible {
    private static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()
    private static let ymd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    public init?(_ string: String) {
        if let date = Self.ymd.date(from: string) {
            self = date
            return
        }
        if let date = Self.iso8601.date(from: string) {
            self = date
            return
        }
        return nil
    }
}

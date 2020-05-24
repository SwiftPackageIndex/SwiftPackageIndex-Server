import Foundation


extension DefaultStringInterpolation {
    mutating func appendInterpolation(date: Date, relativeTo referenceDate: Date) {
        appendInterpolation(Self.localizedString(for: date, relativeTo: referenceDate))
    }

    mutating func appendInterpolation(inWords timeDifference: TimeInterval) {
        appendInterpolation(Self.distancePhrase(timeDifference))
    }

    static func localizedString(for date: Date, relativeTo reference: Date) -> String {
        let delta = date.timeIntervalSince(reference)
        let phrase = Self.distancePhrase(delta)
        return delta >= 0 ? "in \(phrase)" : "\(phrase) ago"
    }

    static func distancePhrase(_ delta: TimeInterval) -> String {
        let m = 60
        let H = 60*m
        let d = 24*H
        let M = 30*d   // crude...
        let Y = 365*d  // ignore leap years
        let seconds = Int(round(abs(delta)))
        let minutes = seconds/m
        let hours = seconds/H
        let days = seconds/d
        let months = seconds/M
        let years = seconds/Y
        switch seconds {
            case 0:
                return "0 seconds"
            case 0 ..< 30:
                return "less than a minute"
            case 30 ..< m + 30:
                return "1 minute"
            case m + 30 ..< 44*m + 30:
                return pluralizedCount(minutes, singular: "minute")
            case 44*m + 30 ..< 89*m + 30:
                return "about 1 hour"
            case 89*m + 30 ..< 24*H - 30:
                return "about " + pluralizedCount(hours, singular: "hour")
            case 24*H - 30 ..< 42*H - 30:
                return "1 day"
            case 42*H - 30 ..< 30*d - 30:
                return pluralizedCount(days, singular: "day")
            case 30*d - 30 ..< 45*d - 30:
                return "about 1 month"
            case 45*d - 30 ..< 60*d - 30:
                return "about 2 months"
            case 60*d - 30 ..< Y - 1:
                return pluralizedCount(months, singular: "month")
            case Y ..< Y + 3*M:
                return "about 1 year"
            case Y + 3*M ..< Y + 9*M:
                return "over 1 year"
            case Y + 9*M ..< 2*Y - 1:
                return "almost 2 years"
            default:
                return pluralizedCount(years, singular: "year")
        }
    }

}

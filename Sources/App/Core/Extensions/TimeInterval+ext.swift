import Foundation


extension TimeInterval {
    static func days(_ value: Double) -> Self { value * .hours(24) }
    static func hours(_ value: Double) -> Self { value * .minutes(60) }
    static func minutes(_ value: Double) -> Self { value * .seconds(60) }
    static func seconds(_ value: Double) -> Self { value }

    var inHours: Double { inMinutes/60 }
    var inMinutes: Double { self/60 }
}

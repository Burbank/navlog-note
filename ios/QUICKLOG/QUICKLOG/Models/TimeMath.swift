import Foundation

enum TimeMath {
    static let minutesPerDay = 24 * 60

    static func digits(in raw: String) -> String {
        raw.filter(\.isNumber)
    }

    static func normalizeIATA(_ raw: String) -> String {
        let letters = raw.uppercased().filter { $0.isLetter && $0.isASCII }
        return letters.count > 3 ? String(letters.suffix(3)) : letters
    }

    static func formatClock(_ digits: String, maxLen: Int = 4) -> String {
        let d = String(digits.filter(\.isNumber).prefix(maxLen))
        if d.count <= 2 { return d }
        let hh = String(d.prefix(2))
        let mm = String(d.dropFirst(2))
        return hh + ":" + mm
    }

    static func minutes(_ time: String) -> Int? {
        let t = time.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.uppercased() == "N/A" || t.uppercased() == "NA" { return nil }
        let parts = t.split(separator: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), h >= 0, h < 24, m >= 0, m < 60 {
            return h * 60 + m
        }
        let d = digits(in: t)
        guard d.count == 4, let h = Int(d.prefix(2)), let m = Int(d.suffix(2)), h < 24, m < 60 else { return nil }
        return h * 60 + m
    }

    static func hhmm(_ mins: Int) -> String {
        let wrapped = ((mins % minutesPerDay) + minutesPerDay) % minutesPerDay
        return String(format: "%02d:%02d", wrapped / 60, wrapped % 60)
    }

    static func addMinutes(_ time: String, _ delta: Int) -> String {
        guard let base = minutes(time) else { return "" }
        return hhmm(base + delta)
    }

    /// Duration strings such as S26 `"8:10"` or `"11:55"` (not clock-of-day).
    static func durationMinutes(_ str: String) -> Int? {
        let t = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let parts = t.split(separator: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), m >= 0, m < 60 {
            return h * 60 + m
        }
        return nil
    }

    static func durationString(_ total: Int) -> String {
        let n = max(0, total)
        return String(format: "%d:%02d", n / 60, n % 60)
    }

    static func minutesBetweenAllowingMidnight(_ end: Int, _ start: Int) -> Int {
        let d = end - start
        return d >= 0 ? d : d + minutesPerDay
    }

    static func subtractTimes(_ end: String, _ start: String) -> String {
        guard let e = minutes(end), let s = minutes(start) else { return "—" }
        return durationString(minutesBetweenAllowingMidnight(e, s))
    }

    static func utcNowMinutes() -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let d = Date()
        return cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d)
    }

    static func formatUTCDate(_ date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: date).uppercased()
    }

    static func parseLogDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd MMM yyyy"
        if let d = f.date(from: str.trimmingCharacters(in: .whitespaces)) { return d }
        f.dateFormat = "dd MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: str.uppercased())
    }

    static func daysAgoText(_ dateStr: String) -> String {
        guard let dep = parseLogDate(dateStr) else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = cal.startOfDay(for: Date())
        let day = cal.startOfDay(for: dep)
        let n = cal.dateComponents([.day], from: day, to: today).day ?? 0
        if n == 0 { return "today" }
        if n == 1 { return "1 day ago" }
        if n > 1 { return "\(n) days ago" }
        if n == -1 { return "tomorrow" }
        return "in \(-n) days"
    }

    static func appendUTC(_ value: String, time: Bool = false, weight: Bool = false) -> String {
        let v = value.trimmingCharacters(in: .whitespaces)
        if v.isEmpty { return "" }
        if time {
            if v.uppercased() == "N/A" { return "N/A" }
            if v.uppercased().hasSuffix("UTC") { return v }
            return v + " UTC"
        }
        if weight {
            if v.uppercased().hasSuffix("MT") { return v }
            return v + " MT"
        }
        return v
    }
}

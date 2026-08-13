import Foundation

enum CrewRestPattern: String, CaseIterable, Identifiable {
    case rrr, twoR = "2r"
    var id: String { rawValue }
    var title: String { self == .twoR ? "6 rests: R R R 2R 2R 2R" : "3 rests: R R R" }
    var shortTitle: String { self == .twoR ? "R R R 2R 2R 2R" : "R R R" }
    var units: Int { self == .twoR ? 9 : 3 }
    var weights: [Int] { self == .twoR ? [1, 1, 1, 2, 2, 2] : [1, 1, 1] }
    var labels: [String] { self == .twoR ? ["R", "R", "R", "2R", "2R", "2R"] : ["Rest 1", "Rest 2", "Rest 3"] }
}

struct CrewRestRow: Identifiable, Equatable {
    var id: Int
    var label: String
    var lengthMinutes: Int
    var startMin: Int
    var endMin: Int
    var startError: Bool = false
    var endError: Bool = false

    var length: String { TimeMath.durationString(lengthMinutes) }
    var start: String { TimeMath.hhmm(startMin) }
    var end: String { TimeMath.hhmm(endMin) }
    var displayLabel: String {
        label.lowercased().contains("rest") ? label : "Rest \(id + 1) · \(label)"
    }
}

struct CrewRestPlan: Equatable {
    var rows: [CrewRestRow]
    var hint: String
    var title: String
}

enum CrewRestCalc {
    static let block2RMin = 11 * 60
    static let afterAirMin = 30
    static let afterOffMin = 45
    static let beforeOnMin = 40
    static let pauseDefault = 5
    static let pfMinMinutes = 2 * 60
    static let onGrossSlack = 2 * 60
    static let beforeOriginMin = 20 * 60

    static func allocate(total: Int, weights: [Int]) -> [Int] {
        let n = weights.count
        var lengths = Array(repeating: 0, count: n)
        let units = weights.reduce(0, +)
        guard n > 0, total > 0, units > 0 else { return lengths }
        var lastIdx = n - 1
        while lastIdx > 0 && weights[lastIdx] == 0 { lastIdx -= 1 }
        var used = 0
        for i in 0..<n where i != lastIdx {
            let len = (total * weights[i]) / units
            lengths[i] = len
            used += len
        }
        lengths[lastIdx] = total - used
        return lengths
    }

    static func relMinutes(origin: Int, t: Int) -> Int {
        let r = TimeMath.minutesBetweenAllowingMidnight(t, origin)
        return r >= beforeOriginMin ? r - TimeMath.minutesPerDay : r
    }

    static func compute(start: String, end: String, pause: Int, pattern: CrewRestPattern, pfMin2h: Bool) -> CrewRestPlan {
        let metaTitle = pattern.title
        guard let startM = TimeMath.minutes(start), let endM = TimeMath.minutes(end) else {
            return CrewRestPlan(rows: [], hint: "Enter timeframe start and end (HH:MM).", title: metaTitle)
        }
        let n = pattern.weights.count
        let window = TimeMath.minutesBetweenAllowingMidnight(endM, startM)
        let restTotal = window - max(0, pause) * (n - 1)
        if restTotal < pattern.units {
            return CrewRestPlan(
                rows: [],
                hint: "Window too short for this pattern and changeover. Widen the timeframe or reduce the changeover.",
                title: metaTitle
            )
        }
        var lengths = allocate(total: restTotal, weights: pattern.weights)
        var hint = ""
        if pfMin2h && n >= 3 {
            let mid = n / 2
            if lengths[mid] < pfMinMinutes {
                if restTotal < pfMinMinutes {
                    lengths = Array(repeating: 0, count: n)
                    lengths[mid] = restTotal
                    hint = "Mid rest is under 2 hours — legally insufficient for PF."
                } else {
                    let other = pattern.weights.enumerated().map { $0.offset == mid ? 0 : $0.element }
                    lengths = allocate(total: restTotal - pfMinMinutes, weights: other)
                    lengths[mid] = pfMinMinutes
                }
            }
        }
        var rows: [CrewRestRow] = []
        var t = startM
        for i in 0..<n {
            let len = lengths[i]
            let st = t
            let en = (t + len) % TimeMath.minutesPerDay
            rows.append(CrewRestRow(id: i, label: pattern.labels[i], lengthMinutes: len, startMin: st, endMin: en))
            t = (en + (i < n - 1 ? pause : 0)) % TimeMath.minutesPerDay
        }
        return CrewRestPlan(rows: rows, hint: hint, title: metaTitle)
    }

    static func suggest(from form: FormState) -> (pattern: CrewRestPattern, start: String, end: String, route: String) {
        let dep = form.logDep
        let arr = form.logArr
        let s26 = form.s26
        let s26Min = TimeMath.durationMinutes(s26)
        let air = form.isSim ? "" : form.airborne
        let off = form.offBlocks
        let on = form.onBlocks
        var start = ""
        if TimeMath.minutes(air) != nil {
            start = TimeMath.addMinutes(air, afterAirMin)
        } else if TimeMath.minutes(off) != nil {
            start = TimeMath.addMinutes(off, afterOffMin)
        }
        let cruise = TimeMath.minutes(air) != nil ? air : off
        var end = ""
        if TimeMath.minutes(on) != nil {
            end = TimeMath.addMinutes(on, -beforeOnMin)
        } else if TimeMath.minutes(cruise) != nil, let s26Min {
            end = TimeMath.addMinutes(cruise, s26Min - beforeOnMin)
        }
        var blockMin: Int?
        if TimeMath.minutes(cruise) != nil, let onM = TimeMath.minutes(on), let cM = TimeMath.minutes(cruise) {
            blockMin = TimeMath.minutesBetweenAllowingMidnight(onM, cM)
        } else {
            blockMin = s26Min
        }
        let pattern: CrewRestPattern = (blockMin ?? 0) >= block2RMin ? .twoR : .rrr
        var route = ""
        if !dep.isEmpty && !arr.isEmpty && dep != "SIM" {
            route = "\(dep)–\(arr)"
            if !s26.isEmpty { route += " · S26 \(s26)" }
            if let blockMin, let s26Min, blockMin != s26Min, TimeMath.minutes(cruise) != nil, TimeMath.minutes(on) != nil {
                route += " · actual \(TimeMath.durationString(blockMin))"
            }
        }
        return (pattern, start, end, route)
    }
}

struct CrewRestSession: Equatable {
    var pattern: CrewRestPattern = .rrr
    var start: String = ""
    var end: String = ""
    var changeover: Int = CrewRestCalc.pauseDefault
    var pfMin2h: Bool = true
    var alertAtEnd: Bool = true
    var tableSeen: Bool = false
}

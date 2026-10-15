import Foundation

struct FormState: Codable, Equatable {
    var security: String = "performed"
    var pdc: String = ""
    var ctot: String = "N/A"
    var atis: String = ""
    var rwySid: String = ""
    var climbTo: String = ""
    var transponder: String = ""
    var fuel: String = ""
    var tom: String = ""
    var calcAt: String = ""
    var rwy: String = ""
    var intersection: String = "FULL"
    var rvsmL: String = ""
    var rvsmR: String = ""
    var rvsmSby: String = ""
    var mnps: String = "N/A"
    var arrAtis: String = ""
    var ldis: String = ""
    var logPf: Bool = false
    var logPicSelf: Bool = false
    var logAcft: String = "CKA"
    var logTol: Int = 3
    var logPic: String = ""
    var logRemark: String = ""
    var logDeptDate: String = ""
    var logDep: String = ""
    var logArr: String = "AMS"
    var offBlocks: String = ""
    var airborne: String = ""
    var touchdown: String = ""
    var onBlocks: String = ""

    var isSim: Bool { logAcft.trimmingCharacters(in: .whitespaces).uppercased() == "SIM" }

    var registration: String {
        isSim ? "SIM" : "PH-" + logAcft.trimmingCharacters(in: .whitespaces).uppercased()
    }

    var blockTime: String {
        TimeMath.subtractTimes(onBlocks, offBlocks)
    }

    var flightTime: String {
        if isSim { return "N/A" }
        return TimeMath.subtractTimes(touchdown, airborne)
    }

    var s26: String { BlockTimes.block(dep: logDep, arr: logArr) }

    var estimatedOnBlocks: String {
        guard let off = TimeMath.minutes(offBlocks), let s26m = TimeMath.durationMinutes(s26) else { return "" }
        return TimeMath.hhmm(off + s26m)
    }

    var rvsmDiffExceeded: Bool {
        guard let l = Int(TimeMath.digits(in: rvsmL)), let r = Int(TimeMath.digits(in: rvsmR)) else { return false }
        return abs(l - r) > 200
    }

    func asLogLeg() -> LogLeg {
        LogLeg(
            logAcft: logAcft,
            logPf: logPf,
            logPicSelf: logPicSelf,
            logPic: logPic,
            logRemark: logRemark,
            logDep: logDep,
            logArr: logArr,
            logDeptDate: logDeptDate.isEmpty ? TimeMath.formatUTCDate() : logDeptDate,
            logTol: isSim ? logTol : nil,
            offBlocks: offBlocks,
            airborne: isSim ? "N/A" : airborne,
            touchdown: isSim ? "N/A" : touchdown,
            onBlocks: onBlocks
        )
    }

    mutating func apply(leg: LogLeg) {
        logAcft = leg.logAcft
        logPf = leg.logPf
        logPicSelf = leg.logPicSelf
        logPic = leg.logPic
        logRemark = leg.logRemark
        logDep = leg.logDep
        logArr = leg.logArr
        logDeptDate = leg.logDeptDate
        if let tol = leg.logTol { logTol = tol }
        offBlocks = leg.offBlocks
        airborne = leg.airborne
        touchdown = leg.touchdown
        onBlocks = leg.onBlocks
    }

    mutating func enterSim() {
        logAcft = "SIM"
        logDep = "SIM"
        logArr = "SIM"
        airborne = "N/A"
        touchdown = "N/A"
        logPf = true
        if onBlocks.isEmpty, TimeMath.minutes(offBlocks) != nil {
            onBlocks = TimeMath.addMinutes(offBlocks, 4 * 60)
        }
    }

    mutating func leaveSim(previousAcft: String, dep: String, arr: String) {
        logAcft = previousAcft.isEmpty || previousAcft == "SIM" ? "CKA" : previousAcft
        logDep = dep
        logArr = arr
        if airborne.uppercased() == "N/A" { airborne = "" }
        if touchdown.uppercased() == "N/A" { touchdown = "" }
    }

    mutating func clearOperationalFields() {
        let keepPic = logPic
        let keepRemark = logRemark
        let keepDate = logDeptDate
        let keepAcft = logAcft
        let keepDep = logDep
        let keepArr = logArr
        let keepPicSelf = logPicSelf
        self = FormState()
        logPic = keepPic
        logRemark = keepRemark
        logDeptDate = keepDate
        logAcft = keepAcft
        logDep = keepDep
        logArr = keepArr
        logPicSelf = keepPicSelf
        if isSim { enterSim() }
    }
}

struct LogLeg: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var logAcft: String
    var logPf: Bool
    var logPicSelf: Bool
    var logPic: String
    var logRemark: String
    var logDep: String
    var logArr: String
    var logDeptDate: String
    var logTol: Int?
    var offBlocks: String
    var airborne: String
    var touchdown: String
    var onBlocks: String

    var isSim: Bool {
        logAcft.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "PH-", with: "") == "SIM"
    }

    var route: String { isSim ? "" : "\(logDep)→\(logArr)" }
    var registration: String { isSim ? "SIM" : logAcft }
    var block: String { TimeMath.subtractTimes(onBlocks, offBlocks) }
    var flight: String { isSim ? "N/A" : TimeMath.subtractTimes(touchdown, airborne) }
    var task: String { logPf ? "PF" : "PM" }
    var simTolCredits: Int { max(0, min(9, logTol ?? 3)) }

    enum CodingKeys: String, CodingKey {
        case id, logAcft, logPf, logPicSelf, logPic, logRemark, logDep, logArr
        case logDeptDate, logTol, offBlocks, airborne, touchdown, onBlocks
    }

    init(
        id: UUID = UUID(),
        logAcft: String, logPf: Bool, logPicSelf: Bool, logPic: String, logRemark: String,
        logDep: String, logArr: String, logDeptDate: String, logTol: Int?,
        offBlocks: String, airborne: String, touchdown: String, onBlocks: String
    ) {
        self.id = id
        self.logAcft = logAcft
        self.logPf = logPf
        self.logPicSelf = logPicSelf
        self.logPic = logPic
        self.logRemark = logRemark
        self.logDep = logDep
        self.logArr = logArr
        self.logDeptDate = logDeptDate
        self.logTol = logTol
        self.offBlocks = offBlocks
        self.airborne = airborne
        self.touchdown = touchdown
        self.onBlocks = onBlocks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        logAcft = try c.decodeIfPresent(String.self, forKey: .logAcft) ?? ""
        if let flag = try? c.decode(Bool.self, forKey: .logPf) {
            logPf = flag
        } else {
            logPf = (try c.decodeIfPresent(String.self, forKey: .logPf) ?? "") == "yes"
        }
        if let flag = try? c.decode(Bool.self, forKey: .logPicSelf) {
            logPicSelf = flag
        } else {
            logPicSelf = (try c.decodeIfPresent(String.self, forKey: .logPicSelf) ?? "") == "yes"
        }
        logPic = try c.decodeIfPresent(String.self, forKey: .logPic) ?? ""
        logRemark = try c.decodeIfPresent(String.self, forKey: .logRemark) ?? ""
        logDep = try c.decodeIfPresent(String.self, forKey: .logDep) ?? ""
        logArr = try c.decodeIfPresent(String.self, forKey: .logArr) ?? ""
        logDeptDate = try c.decodeIfPresent(String.self, forKey: .logDeptDate) ?? ""
        logTol = try c.decodeIfPresent(Int.self, forKey: .logTol)
        offBlocks = try c.decodeIfPresent(String.self, forKey: .offBlocks) ?? ""
        airborne = try c.decodeIfPresent(String.self, forKey: .airborne) ?? ""
        touchdown = try c.decodeIfPresent(String.self, forKey: .touchdown) ?? ""
        onBlocks = try c.decodeIfPresent(String.self, forKey: .onBlocks) ?? ""
    }
}

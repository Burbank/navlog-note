import Foundation
import UIKit

enum CopyBuilder {
    static let backupReminder = """
    Thank you for creating a backup. QUICKLOG Logbook is primarily intended for fast access to a temporary logbook.
    After you safely store these flights (in a proper logbook), you can delete their lines by check-marking them and deleting with [CLEAR MARKED LINES] to start logging a new cycle of flights.
    Note that this also affects the RECENCY reminder, so you may want to keep a few PF flights in the app.
    """

    static func deptText(_ v: FormState) -> String {
        var lines = [
            "___________________________________", "",
            "Security check: \(TimeMath.appendUTC(v.security))", "",
            "DEPT ATIS: \(TimeMath.appendUTC(v.atis))", "",
            "CTOT:  \(TimeMath.appendUTC(v.ctot, time: true))", "",
            "PDC/ACARS ref: \(v.pdc.isEmpty ? "N/A" : v.pdc)", "",
            "Departure clearance:", "",
            "* Runway and SID: \(v.rwySid)", "",
            "* Climb to:  \(v.climbTo)", "",
            "* Transponder: \(v.transponder)", "",
            "___________________________________", "",
            "Fuel when starting engines: \(TimeMath.appendUTC(v.fuel, weight: true))", "",
            "TOM:    \(TimeMath.appendUTC(v.tom, weight: true))", "",
            "DSPERFO:", "",
            "* Calculated at     : \(TimeMath.appendUTC(v.calcAt, time: true))", "",
            "* RWY.                    : \(v.rwy)", "",
            "* INTERSECTION :    \(v.intersection)", "",
            "___________________________________", "",
            "Before RVSM entry   L: \(v.rvsmL)                    R: \(v.rvsmR)                    SBY: \(v.rvsmSby)", ""
        ]
        if v.mnps == "PERFORMED" {
            lines.append(contentsOf: ["MNPS RTE CHECKS.   PERFORMED.", ""])
        }
        return lines.joined(separator: "\n")
    }

    static func arrText(_ v: FormState) -> String {
        let ldis = String(TimeMath.digits(in: v.ldis).prefix(4))
        return "Landing airport ATIS: \(v.arrAtis)\nCalculated landing distance: \(ldis.isEmpty ? "" : ldis + " m")"
    }

    static func logLine(_ v: FormState) -> String {
        let date = v.logDeptDate.isEmpty ? TimeMath.formatUTCDate() : v.logDeptDate
        let air = v.airborne.uppercased() == "N/A" ? "N/A" : TimeMath.appendUTC(v.airborne, time: true)
        let td = v.touchdown.uppercased() == "N/A" ? "N/A" : TimeMath.appendUTC(v.touchdown, time: true)
        var lines = [
            "ACFT: \(v.registration)",
            "PIC: \(v.logPic)",
            "Acting as PIC: \(v.logPicSelf ? "yes" : "no")",
            "Pilot Flying: \(v.logPf ? "yes" : "no")"
        ]
        if !v.logRemark.isEmpty { lines.append("REMARK: \(v.logRemark)") }
        if !v.isSim {
            lines.append("DEP: \(v.logDep)")
            lines.append("ARR: \(v.logArr)")
        }
        lines.append("DEPT DATE: \(date)")
        lines.append(contentsOf: [
            "OFF BLOCKS: \(TimeMath.appendUTC(v.offBlocks, time: true))",
            "AIRBORNE: \(air)",
            "TOUCHDOWN: \(td)",
            "ON BLOCKS: \(TimeMath.appendUTC(v.onBlocks, time: true))",
            "BLOCK: \(v.blockTime == "—" ? "" : v.blockTime)",
            "FLIGHT: \(v.flightTime == "—" ? "" : v.flightTime)"
        ])
        return lines.joined(separator: "\n")
    }

    static func markedTable(_ legs: [LogLeg]) -> (text: String, html: String) {
        let rows = legs.reversed()
        let headers = ["DEP DATE", "REG", "ROUTE", "OFF BLK", "T/O", "LDG", "ON BLK", "BLOCK", "FLIGHT", "TASK", "PIC", "REMARK"]
        var text = backupReminder + "\n\n" + headers.joined(separator: "\t") + "\n"
        var body = ""
        for leg in rows {
            let cells = [
                leg.logDeptDate, leg.registration, leg.route, leg.offBlocks,
                leg.airborne, leg.touchdown, leg.onBlocks, leg.block, leg.flight,
                leg.task, leg.logPic, leg.logRemark
            ]
            text += cells.joined(separator: "\t") + "\n"
            body += "<tr>" + cells.map { "<td style=\"text-align:center;padding:4px 8px\">\(esc($0))</td>" }.joined() + "</tr>"
        }
        let th = headers.map { "<th style=\"padding:4px 8px\">\(esc($0))</th>" }.joined()
        let html = "<p>\(esc(backupReminder).replacingOccurrences(of: "\n", with: "<br>"))</p><table border=\"1\" cellpadding=\"0\" cellspacing=\"0\" style=\"border-collapse:collapse;font-size:12px\"><thead><tr>\(th)</tr></thead><tbody>\(body)</tbody></table>"
        return (text, html)
    }

    static func markedCSV(_ legs: [LogLeg]) -> String {
        var lines = [backupReminder, "Date,Aircraft ID,Aircraft Type,From,To,Out,Off,On,In,Total Time,PIC,PIC Name,Day Takeoffs,Day Landings,Remarks"]
        for leg in legs.reversed() {
            let date = csvDate(leg.logDeptDate)
            let acftID = leg.isSim ? "SIM" : "PH-\(leg.logAcft)"
            let type = leg.isSim ? "SIM" : "B744"
            let from = leg.isSim ? "SIM" : leg.logDep
            let to = leg.isSim ? "SIM" : leg.logArr
            let picTime = leg.logPicSelf ? leg.block : ""
            let tol = leg.logPf ? (leg.isSim ? String(leg.simTolCredits) : "1") : ""
            let rmk = [leg.task, leg.logRemark].filter { !$0.isEmpty }.joined(separator: " · ")
            let cols = [date, acftID, type, from, to, leg.offBlocks, leg.airborne, leg.touchdown, leg.onBlocks, leg.block, picTime, leg.logPic, tol, tol, rmk]
            lines.append(cols.map(csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n")
    }

    static func crewRestNote(plan: CrewRestPlan, changeover: Int, route: String) -> (text: String, html: String) {
        let head = ["CREW REST", plan.shortTitle, route].filter { !$0.isEmpty }.joined(separator: "  ")
        var lines = [head, "Changeover \(changeover) min", "", "Rest\t   LENGTH\tSTART\tEND"]
        for row in plan.rows {
            lines.append([row.label, row.length, row.start, row.end].joined(separator: "\t"))
        }
        if !plan.hint.isEmpty { lines.append(contentsOf: ["", plan.hint]) }
        let text = lines.joined(separator: "\n")
        let th = ["Rest", "   LENGTH", "START", "END"].map { "<th style=\"padding:6px 12px;text-align:center\">\(esc($0))</th>" }.joined()
        let body = plan.rows.map { row in
            "<tr><td style=\"text-align:left;padding:6px 12px\">\(esc(row.label))</td><td style=\"text-align:center;padding:6px 12px\">\(esc(row.length))</td><td style=\"text-align:center;padding:6px 12px\">\(esc(row.start))</td><td style=\"text-align:center;padding:6px 12px\">\(esc(row.end))</td></tr>"
        }.joined()
        let html = "<p>\(esc(head))<br>Changeover \(changeover) min</p><table border=\"1\" cellpadding=\"0\" cellspacing=\"0\" style=\"border-collapse:collapse;font-size:12px\"><thead><tr>\(th)</tr></thead><tbody>\(body)</tbody></table>"
        return (text, html)
    }

    static func copy(_ text: String, html: String? = nil) {
        if let html {
            UIPasteboard.general.items = [[
                "public.utf8-plain-text": text,
                "public.html": html
            ]]
        } else {
            UIPasteboard.general.string = text
        }
    }

    static func openFlight() {
        if let url = URL(string: "aviobook.ng.efb://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    static func openDSPerfo() {
        if let url = URL(string: "com.klm.dynamicsource://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private static func csvDate(_ s: String) -> String {
        guard let d = TimeMath.parseLogDate(s) else { return s }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd-MMM-yyyy"
        return f.string(from: d)
    }
}

private extension CrewRestPlan {
    var shortTitle: String {
        title.contains("2R") ? "R R R 2R 2R 2R" : "R R R"
    }
}

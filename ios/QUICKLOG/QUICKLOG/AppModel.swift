import Combine
import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var form: FormState
    @Published var logbook: [LogLeg]
    @Published var settings: Store.Settings
    @Published var undoSnap: FormState?
    @Published var crew: CrewRestSession
    @Published var toast: String = ""
    @Published var alertMessage: String?
    @Published var confirmMessage: String?
    @Published var showPICSetup = false
    @Published var showRemark = false
    @Published var showCrewRest = false
    @Published var crewTableOpen = false
    @Published var marked: Set<UUID> = []
    @Published var extraAirports: [String] = []
    @Published var now = Date()
    private var lastLogKey = ""

    private var saveTask: Task<Void, Never>?
    private var confirmAction: (() -> Void)?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var timerBag = Set<AnyCancellable>()

    var palette: Palette {
        let bright = UITraitCollection.current.userInterfaceStyle == .light
        return AppTheme.palette(mode: settings.theme, systemBright: bright)
    }

    var airports: [String] {
        var list = BlockTimes.airports + extraAirports
        if form.isSim {
            if !list.contains("SIM") { list.insert("SIM", at: 0) }
        }
        return Array(Set(list)).sorted()
    }

    var crewSuggestion: (pattern: CrewRestPattern, start: String, end: String, route: String) {
        CrewRestCalc.suggest(from: form)
    }

    var crewPlan: CrewRestPlan {
        CrewRestCalc.compute(
            start: crew.start,
            end: crew.end,
            pause: crew.changeover,
            pattern: crew.pattern,
            pfMin2h: crew.pfMin2h
        )
    }

    var startDerived: Bool {
        let s = crewSuggestion
        return TimeMath.minutes(crew.start) != nil && TimeMath.minutes(s.start) == TimeMath.minutes(crew.start)
    }

    var endDerived: Bool {
        let s = crewSuggestion
        return TimeMath.minutes(crew.end) != nil && TimeMath.minutes(s.end) == TimeMath.minutes(crew.end)
    }

    var pf90: Int { countPF(simOnly: false) }
    var pf90Sim: Int { countPF(simOnly: true) }

    init() {
        let store = Store.shared
        var loaded = store.loadForm()
        var settings = store.loadSettings()
        if loaded.logDep.isEmpty {
            loaded.logDep = BlockTimes.detectDepAirport()
            loaded.logArr = BlockTimes.defaultArr(for: loaded.logDep)
        }
        if loaded.logDeptDate.isEmpty {
            loaded.logDeptDate = TimeMath.formatUTCDate()
        }
        self.form = loaded
        self.logbook = store.loadLog()
        self.settings = settings
        self.extraAirports = settings.extraAirports
        self.crew = CrewRestSession()
        self.showPICSetup = !settings.askedPIC
        refreshCrewFromLog(force: true)
        timer.sink { [weak self] date in
            self?.now = date
        }.store(in: &timerBag)
    }

    func persistSoon() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            await self?.persistNow()
        }
    }

    func persistNow() {
        var s = settings
        s.extraAirports = extraAirports
        if !form.isSim {
            s.lastNonSimAircraft = form.logAcft
            s.lastNonSimDep = form.logDep
            s.lastNonSimArr = form.logArr
        }
        settings = s
        Store.shared.saveForm(form)
        Store.shared.saveLog(logbook)
        Store.shared.saveSettings(s)
        rescheduleCrewAlerts()
    }

    func pushUndo() {
        undoSnap = form
    }

    func undo() {
        guard let snap = undoSnap else { return }
        form = snap
        persistSoon()
    }

    func clearForm() {
        pushUndo()
        form.clearOperationalFields()
        persistSoon()
        toast = "Cleared"
    }

    func setTheme(_ mode: ThemeMode) {
        settings.theme = mode
        persistSoon()
    }

    func setAircraft(_ code: String) {
        if code == "SIM" && !form.isSim {
            settings.lastNonSimAircraft = form.logAcft
            settings.lastNonSimDep = form.logDep
            settings.lastNonSimArr = form.logArr
            form.enterSim()
        } else if form.isSim && code != "SIM" {
            form.leaveSim(previousAcft: code, dep: settings.lastNonSimDep.isEmpty ? BlockTimes.detectDepAirport() : settings.lastNonSimDep, arr: settings.lastNonSimArr)
            form.logAcft = code
        } else {
            form.logAcft = code
        }
        persistSoon()
        refreshCrewFromLog(force: false)
    }

    func setDep(_ code: String) {
        let iata = TimeMath.normalizeIATA(code)
        form.logDep = iata
        if iata == "SIM" { setAircraft("SIM"); return }
        if form.logArr.isEmpty || BlockTimes.depToArr[iata] != nil {
            form.logArr = BlockTimes.defaultArr(for: iata)
        }
        persistSoon()
        refreshCrewFromLog(force: false)
    }

    func addAirport(_ raw: String, dep: Bool) {
        let iata = TimeMath.normalizeIATA(raw)
        guard iata.count == 3 else { return }
        if iata == "SIM" { setAircraft("SIM"); return }
        if !BlockTimes.airports.contains(iata) && !extraAirports.contains(iata) {
            extraAirports.append(iata)
        }
        if dep { setDep(iata) } else { form.logArr = iata; persistSoon(); refreshCrewFromLog(force: false) }
    }

    func saveDefaultPIC(_ name: String) {
        settings.defaultPIC = name.trimmingCharacters(in: .whitespaces)
        settings.askedPIC = true
        showPICSetup = false
        if !settings.defaultPIC.isEmpty {
            if form.logPic.isEmpty { form.logPic = settings.defaultPIC }
            form.logPicSelf = true
        }
        persistSoon()
    }

    func applyPICName(_ name: String) {
        form.logPic = name
        if !settings.defaultPIC.isEmpty {
            form.logPicSelf = name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(settings.defaultPIC) == .orderedSame
        }
        persistSoon()
    }

    func addToLog(force: Bool = false) {
        if TimeMath.minutes(form.offBlocks) == nil && TimeMath.minutes(form.onBlocks) == nil {
            alertMessage = "Need OFF or ON time to add a log line."
            return
        }
        if !force {
            var missing: [String] = []
            if form.logDeptDate.isEmpty { missing.append("DEP DATE") }
            if form.logAcft.isEmpty { missing.append("ACFT") }
            if !form.isSim {
                if form.logDep.isEmpty { missing.append("DEP") }
                if form.logArr.isEmpty { missing.append("ARR") }
            }
            if TimeMath.minutes(form.offBlocks) == nil { missing.append("OFF BLOCKS") }
            if TimeMath.minutes(form.onBlocks) == nil { missing.append("ON BLOCKS") }
            if !missing.isEmpty {
                confirmMessage = "Log line incomplete (\(missing.joined(separator: ", "))).\n\nSave anyway?"
                confirmAction = { [weak self] in self?.addToLog(force: true) }
                return
            }
        }
        pushUndo()
        let leg = form.asLogLeg()
        logbook.insert(leg, at: 0)
        if logbook.count > Store.logStoreMax { logbook = Array(logbook.prefix(Store.logStoreMax)) }
        CopyBuilder.copy(CopyBuilder.logLine(form))
        if !form.isSim {
            form.offBlocks = ""
            form.airborne = ""
            form.touchdown = ""
            form.onBlocks = ""
        }
        persistNow()
        toast = "Line added to log · Copied"
    }

    func editMarked() {
        guard marked.count == 1, let id = marked.first, let leg = logbook.first(where: { $0.id == id }) else {
            alertMessage = "Mark exactly one line to edit."
            return
        }
        pushUndo()
        form.apply(leg: leg)
        persistSoon()
        toast = "Loaded marked line"
    }

    func clearMarked() {
        guard !marked.isEmpty else { return }
        confirmMessage = "Remove \(marked.count) marked log line(s)?"
        confirmAction = { [weak self] in
            guard let self else { return }
            self.logbook.removeAll { self.marked.contains($0.id) }
            self.marked.removeAll()
            self.persistNow()
        }
    }

    func copyDept() {
        pushUndo()
        CopyBuilder.copy(CopyBuilder.deptText(form))
        CopyBuilder.openFlight()
        toast = "Copied departure text"
    }

    func copyArr() {
        CopyBuilder.copy(CopyBuilder.arrText(form))
        CopyBuilder.openFlight()
        toast = "Copied arrival text"
    }

    func copyMarkedTable() {
        let legs = logbook.filter { marked.contains($0.id) }
        guard !legs.isEmpty else { alertMessage = "Mark one or more lines first."; return }
        let pair = CopyBuilder.markedTable(legs)
        CopyBuilder.copy(pair.text, html: pair.html)
        toast = "Copied marked table"
    }

    func copyMarkedCSV() {
        let legs = logbook.filter { marked.contains($0.id) }
        guard !legs.isEmpty else { alertMessage = "Mark one or more lines first."; return }
        CopyBuilder.copy(CopyBuilder.markedCSV(legs))
        toast = "Copied marked CSV"
    }

    func confirmOK() {
        confirmAction?()
        confirmAction = nil
        confirmMessage = nil
    }

    func confirmCancel() {
        confirmAction = nil
        confirmMessage = nil
    }

    func openCrewRest() {
        guard !form.isSim else { return }
        refreshCrewFromLog(force: false)
        showCrewRest = true
        crewTableOpen = crew.tableSeen && !crewPlan.rows.isEmpty
        NotificationService.requestPermission()
    }

    func resetCrewDefaults() {
        refreshCrewFromLog(force: true)
        crew.pfMin2h = true
        crewTableOpen = false
        persistSoon()
    }

    func refreshCrewFromLog(force: Bool) {
        let key = [form.logDep, form.logArr, form.offBlocks, form.airborne, form.onBlocks].joined(separator: "|")
        let s = crewSuggestion
        if force || lastLogKey != key {
            crew.pattern = s.pattern
            crew.start = s.start
            crew.end = s.end
            lastLogKey = key
        }
        rescheduleCrewAlerts()
    }

    func showCrewTable() {
        crew.tableSeen = true
        crewTableOpen = true
        rescheduleCrewAlerts()
    }

    func copyCrewNote() {
        let plan = crewPlan
        guard !plan.rows.isEmpty else { alertMessage = "Enter start and end first"; return }
        let route = (form.logDep.isEmpty || form.logArr.isEmpty) ? "" : "\(form.logDep)–\(form.logArr)"
        let pair = CopyBuilder.crewRestNote(plan: plan, changeover: crew.changeover, route: route)
        CopyBuilder.copy(pair.text, html: pair.html)
        CopyBuilder.openFlight()
        toast = "Copied crew rest note"
    }

    func rescheduleCrewAlerts() {
        NotificationService.cancelAllCrewRest()
        guard crew.alertAtEnd, crew.tableSeen, !form.isSim else { return }
        let plan = crewPlan
        guard !plan.rows.isEmpty else { return }
        let route = (form.logDep.isEmpty || form.logArr.isEmpty) ? "" : "\(form.logDep)–\(form.logArr)"
        NotificationService.schedule(rows: plan.rows, route: route)
    }

    private func countPF(simOnly: Bool) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = cal.startOfDay(for: Date())
        let cutoff = cal.date(byAdding: .day, value: -90, to: today) ?? today
        var n = 0
        for leg in logbook {
            guard leg.logPf else { continue }
            if simOnly && !leg.isSim { continue }
            guard let dep = TimeMath.parseLogDate(leg.logDeptDate) else { continue }
            let day = cal.startOfDay(for: dep)
            if day < cutoff || day > today { continue }
            n += leg.isSim ? leg.simTolCredits : (simOnly ? 0 : 1)
        }
        return n
    }
}

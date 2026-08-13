import SwiftUI
import UIKit

/// Landscape shell sized for A2903 (iPad Air 11" — 1180×820 pt).
struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) var colorScheme
    @State private var addDep = ""
    @State private var addArr = ""
    @State private var showDate = false

    var body: some View {
        let p = model.palette
        ZStack {
            p.bg.ignoresSafeArea()
            VStack(spacing: 8) {
                toolbar
                HStack(alignment: .top, spacing: 8) {
                    clearanceCard.frame(maxWidth: .infinity)
                    fuelCard.frame(maxWidth: .infinity)
                    VStack(spacing: 8) {
                        rvsmCard
                        QLButton(title: "Copy dept text", kind: .muted, action: model.copyDept)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 250)
                HStack(spacing: 8) {
                    landingRow
                    QLButton(title: "Copy arr text", kind: .muted, action: model.copyArr)
                        .frame(width: 160)
                }
                logEntry
                logActions
                logbook
                footer
            }
            .padding(10)
            overlays
        }
        .preferredColorScheme(model.settings.theme == .bright ? .light : (model.settings.theme == .dim ? .dark : nil))
        .onChange(of: colorScheme) { _, _ in model.objectWillChange.send() }
    }

    private var toolbar: some View {
        let p = model.palette
        return HStack(spacing: 8) {
            Button(action: model.openCrewRest) {
                VStack(spacing: 2) {
                    utcLabel
                    if !model.form.isSim {
                        Text("CREW REST")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                    }
                }
                .foregroundStyle(model.form.isSim ? p.muted : p.btnText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(model.form.isSim ? Color.clear : p.btn)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.line, lineWidth: model.form.isSim ? 1 : 0))
            }
            .buttonStyle(.plain)
            .disabled(model.form.isSim)
            .frame(maxWidth: 180)

            Segmented(value: Binding(get: { model.settings.theme }, set: model.setTheme), items: [
                (.bright, "BRIGHT"), (.dim, "DIM"), (.system, "SYSTEM")
            ])
            .frame(width: 220)

            VStack(spacing: 0) {
                Text("ref OM-A 8.3.2.6")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(p.muted)
                HStack {
                    titleRule
                    Text("QUICKLOG")
                        .font(.system(size: 22, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(p.text)
                    titleRule
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                QLButton(title: "▶ Clear", action: model.clearForm)
                QLButton(title: "Undo", kind: .muted, action: model.undo)
            }
            .frame(width: 220)
        }
    }

    private var titleRule: some View {
        Rectangle().fill(model.palette.line).frame(height: 1)
    }

    private var utcLabel: some View {
        let cal = {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(secondsFromGMT: 0)!
            return c
        }()
        let d = model.now
        let day = String(format: "%02d", cal.component(.day, from: d))
        let hm = String(format: "%02d:%02d", cal.component(.hour, from: d), cal.component(.minute, from: d))
        let sec = String(format: "%02d", cal.component(.second, from: d))
        return HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(day).font(.system(size: 13, weight: .bold, design: .monospaced))
            Text(":").font(.system(size: 13, weight: .bold, design: .monospaced))
            Text(hm).font(.system(size: 20, weight: .heavy, design: .monospaced))
            Text(":").font(.system(size: 13, weight: .bold, design: .monospaced))
            Text(sec).font(.system(size: 13, weight: .bold, design: .monospaced))
        }
    }

    private var clearanceCard: some View {
        Card {
            VStack(spacing: 6) {
                QLTextField(label: "Security check:", text: $model.form.security)
                QLTextField(label: "DEPT ATIS:", text: $model.form.atis, placeholder: "A", autocap: .characters)
                    .onChange(of: model.form.atis) { _, v in
                        model.form.atis = String(v.uppercased().filter(\.isLetter).prefix(1))
                    }
                QLTextField(label: "CTOT:", text: $model.form.ctot, placeholder: "HH:MM or N/A")
                QLTextField(label: "PDC/ACARS ref:", text: $model.form.pdc, placeholder: "000", keyboard: .asciiCapable)
                QLTextField(label: "* Runway and SID:", text: $model.form.rwySid, placeholder: "24L SID name")
                QLTextField(label: "* Climb to:", text: $model.form.climbTo, placeholder: "0000 or FL000", keyboard: .numbersAndPunctuation)
                QLTextField(label: "* Transponder:", text: $model.form.transponder, placeholder: "0000", keyboard: .numberPad) { raw in
                    model.form.transponder = String(raw.filter { "01234567".contains($0) }.prefix(4))
                }
            }
        }
    }

    private var fuelCard: some View {
        Card {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    QLButton(title: "DSPERFO", kind: .muted, action: CopyBuilder.openDSPerfo)
                    QLButton(title: "Paste here", kind: .muted, action: pasteDSPerfo)
                }
                Text("LONGPRESS DSPERFO HEADER \"Calculated 00:00:00z\"")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(model.palette.muted)
                QLTextField(label: "* Calculated at:", text: $model.form.calcAt, placeholder: "HH:MM:SS", keyboard: .numbersAndPunctuation)
                QLTextField(label: "* RWY:", text: $model.form.rwy, placeholder: "24L")
                QLTextField(label: "* INTERSECTION:", text: $model.form.intersection)
                QLTextField(label: "TOM:", text: $model.form.tom, placeholder: "000.0 MT", keyboard: .decimalPad)
                QLTextField(label: "Fuel when starting engines:", text: $model.form.fuel, placeholder: "000.0 MT", keyboard: .decimalPad)
            }
        }
    }

    private var rvsmCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Before RVSM entry")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(model.palette.text)
                    Spacer()
                    if model.form.rvsmDiffExceeded {
                        Text("MAX Δ 200′")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(model.palette.warn)
                    }
                }
                HStack(spacing: 6) {
                    QLTextField(label: "L:", text: $model.form.rvsmL, placeholder: "0000", keyboard: .numberPad)
                    QLTextField(label: "R:", text: $model.form.rvsmR, placeholder: "0000", keyboard: .numberPad)
                    QLTextField(label: "SBY:", text: $model.form.rvsmSby, placeholder: "0000", keyboard: .numberPad)
                }
                HStack {
                    Text("MNPS RTE CHECKS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.palette.muted)
                    Spacer()
                    Segmented(value: $model.form.mnps, items: [("N/A", "N/A"), ("PERFORMED", "PERFORMED")])
                        .frame(width: 180)
                        .onChange(of: model.form.mnps) { _, _ in model.persistSoon() }
                }
            }
        }
    }

    private var landingRow: some View {
        HStack(spacing: 8) {
            QLTextField(label: "ARR ATIS:", text: $model.form.arrAtis, placeholder: "A")
                .onChange(of: model.form.arrAtis) { _, v in
                    model.form.arrAtis = String(v.uppercased().filter(\.isLetter).prefix(1))
                }
            QLTextField(label: "LDIS:", text: $model.form.ldis, placeholder: "0000 M", keyboard: .numberPad)
            Text("8.3.2.6 (c)(7),(8)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(model.palette.muted)
        }
    }

    private var logEntry: some View {
        let p = model.palette
        return HStack(alignment: .top, spacing: 8) {
            Card {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        dateButton
                        tick("RMK", on: Binding(
                            get: { !model.form.logRemark.isEmpty },
                            set: { if $0 { model.showRemark = true } else { model.form.logRemark = ""; model.persistSoon() } }
                        ))
                        if !model.form.logRemark.isEmpty {
                            Button("RMK EDIT") { model.showRemark = true }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(p.accent)
                        }
                        tick("PF", on: $model.form.logPf)
                        Picker("ACFT", selection: Binding(get: { model.form.logAcft }, set: model.setAircraft)) {
                            ForEach(BlockTimes.aircraft, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 72)
                        if model.form.isSim {
                            Picker("TOL", selection: $model.form.logTol) {
                                ForEach(0..<10, id: \.self) { Text("\($0) TOL").tag($0) }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)
                            .onChange(of: model.form.logTol) { _, _ in model.persistSoon() }
                        }
                        Spacer()
                        tick("PIC", on: $model.form.logPicSelf)
                        TextField("PIC name", text: Binding(get: { model.form.logPic }, set: model.applyPICName))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
                    HStack(spacing: 6) {
                        airportPicker(dep: true)
                        TextField("add", text: $addDep)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 52)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: addDep) { _, raw in
                                if TimeMath.normalizeIATA(raw).count == 3 {
                                    model.addAirport(raw, dep: true)
                                    addDep = ""
                                }
                            }
                        airportPicker(dep: false)
                        TextField("add", text: $addArr)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 52)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: addArr) { _, raw in
                                if TimeMath.normalizeIATA(raw).count == 3 {
                                    model.addAirport(raw, dep: false)
                                    addArr = ""
                                }
                            }
                        ClockField(label: "OFF BLOCKS", text: $model.form.offBlocks)
                        ClockField(label: "AIRBORNE", text: $model.form.airborne)
                        ClockField(label: "TOUCHDOWN", text: $model.form.touchdown)
                        ClockField(label: "ON BLOCKS", text: onBlocksBinding)
                        VStack(alignment: .leading, spacing: 2) {
                            sum("BLOCK", model.form.blockTime)
                            if !model.form.s26.isEmpty {
                                Text("S26 \(model.form.s26)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(p.accent)
                            }
                            sum("FLIGHT", model.form.flightTime)
                        }
                        .frame(width: 80)
                    }
                    .onChange(of: model.form.offBlocks) { _, _ in model.refreshCrewFromLog(force: false) }
                    .onChange(of: model.form.airborne) { _, _ in model.refreshCrewFromLog(force: false) }
                    .onChange(of: model.form.onBlocks) { _, _ in model.refreshCrewFromLog(force: false) }
                }
            }
            pf90Badge
        }
        .frame(minHeight: 120)
    }

    private var onBlocksBinding: Binding<String> {
        Binding(
            get: { model.form.onBlocks },
            set: { model.form.onBlocks = $0; model.persistSoon() }
        )
    }

    private func airportPicker(dep: Bool) -> some View {
        Picker(dep ? "DEP" : "ARR", selection: Binding(
            get: { dep ? model.form.logDep : model.form.logArr },
            set: { dep ? model.setDep($0) : { model.form.logArr = $0; model.persistSoon(); model.refreshCrewFromLog(force: false) }() }
        )) {
            ForEach(model.airports, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.menu)
        .frame(width: 72)
    }

    private var dateButton: some View {
        let p = model.palette
        return VStack(spacing: 1) {
            Text(model.form.logDeptDate)
                .font(.system(size: 12, weight: .bold))
            Text("dept utc")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(p.muted)
            Text(TimeMath.daysAgoText(model.form.logDeptDate))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(p.accent)
        }
        .foregroundStyle(p.text)
        .frame(width: 88, height: 48)
        .background(p.field)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { showDate = true }
        .sheet(isPresented: $showDate) {
            VStack {
                DatePicker("DEP DATE UTC", selection: Binding(
                    get: { TimeMath.parseLogDate(model.form.logDeptDate) ?? Date() },
                    set: { model.form.logDeptDate = TimeMath.formatUTCDate($0); model.persistSoon() }
                ), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                Button("Done") { showDate = false }.padding()
            }
            .padding()
        }
    }

    private func tick(_ title: String, on: Binding<Bool>) -> some View {
        Toggle(title, isOn: on)
            .toggleStyle(.button)
            .font(.system(size: 11, weight: .bold))
            .onChange(of: on.wrappedValue) { _, _ in model.persistSoon() }
    }

    private func sum(_ lab: String, _ val: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lab).font(.system(size: 8, weight: .bold)).foregroundStyle(model.palette.muted)
            Text(val).font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundStyle(model.palette.text)
        }
    }

    private var pf90Badge: some View {
        let p = model.palette
        let low = model.pf90 < 3
        return VStack(spacing: 2) {
            Text("\(model.pf90) T/O LDG")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(low ? p.warn : p.text)
            Text("in the last")
            Text("90 days")
            if model.pf90Sim > 0 {
                Text("(\(model.pf90Sim) in sim)")
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(p.muted)
        .frame(width: 88)
        .padding(8)
        .background(p.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
    }

    private var logActions: some View {
        HStack(spacing: 6) {
            QLButton(title: "Edit marked line", kind: .muted, action: model.editMarked)
            QLButton(title: "Copy marked as table", kind: .muted, action: model.copyMarkedTable)
            QLButton(title: "Copy marked as CSV", kind: .muted, action: model.copyMarkedCSV)
            QLButton(title: "Clear marked lines", kind: .warn, action: model.clearMarked)
            QLButton(title: "Add to log", kind: .muted, action: { model.addToLog() })
        }
    }

    private var logbook: some View {
        let p = model.palette
        let headers = ["", "DEP DATE", "REG", "ROUTE", "OFF", "T/O", "LDG", "ON", "BLOCK", "FLIGHT", "TASK", "PIC", "RMK"]
        return Card(padding: 6) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(headers, id: \.self) { h in
                        Text(h)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(p.accent)
                            .frame(maxWidth: .infinity, alignment: h.isEmpty ? .center : .leading)
                    }
                }
                Divider().background(p.line)
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.logbook) { leg in
                            HStack(spacing: 4) {
                                Button {
                                    if model.marked.contains(leg.id) { model.marked.remove(leg.id) } else { model.marked.insert(leg.id) }
                                } label: {
                                    Image(systemName: model.marked.contains(leg.id) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(p.accent)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                logCell(leg.logDeptDate, p)
                                logCell(leg.registration, p)
                                logCell(leg.route, p)
                                logCell(leg.offBlocks, p)
                                logCell(leg.airborne, p)
                                logCell(leg.touchdown, p)
                                logCell(leg.onBlocks, p)
                                logCell(leg.block, p)
                                logCell(leg.flight, p)
                                logCell(leg.task, p)
                                logCell(leg.logPic, p)
                                logCell(leg.logRemark, p)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Also try KLYear and FDP FMS for EASA limits.")
            Spacer()
            Text("Runs locally/offline, sends no data. Author assumes no liability.  v4.6 iPad")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(model.palette.muted)
    }

    @ViewBuilder
    private var overlays: some View {
        if !model.toast.isEmpty {
            Text(model.toast)
                .font(.system(size: 13, weight: .bold))
                .padding(10)
                .background(model.palette.ok)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { model.toast = "" }
                }
        }
        if let msg = model.alertMessage {
            dimmer {
                VStack(spacing: 12) {
                    Text(msg).foregroundStyle(model.palette.text)
                    QLButton(title: "OK", action: { model.alertMessage = nil })
                }
                .padding(16)
                .background(model.palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        if let msg = model.confirmMessage {
            dimmer {
                VStack(spacing: 12) {
                    Text(msg).foregroundStyle(model.palette.text)
                    HStack {
                        QLButton(title: "Cancel", kind: .muted, action: model.confirmCancel)
                        QLButton(title: "OK", action: model.confirmOK)
                    }
                }
                .padding(16)
                .background(model.palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        if model.showPICSetup { PICSetupSheet() }
        if model.showRemark { RemarkSheet() }
        if model.showCrewRest { CrewRestSheet() }
    }

    private func logCell(_ text: String, _ p: Palette) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(p.text)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dimmer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            content()
                .frame(maxWidth: 420)
        }
    }

    private func pasteDSPerfo() {
        guard let clip = UIPasteboard.general.string else { return }
        let re = try? NSRegularExpression(pattern: #"Take-?off:\s+(\S+)(?:\s+\S+)?\s+(\d{1,2}:\d{2}:\d{2})"#, options: .caseInsensitive)
        if let re, let match = re.firstMatch(in: clip, range: NSRange(clip.startIndex..., in: clip)),
           let rwyR = Range(match.range(at: 1), in: clip),
           let timeR = Range(match.range(at: 2), in: clip) {
            model.form.rwy = String(clip[rwyR])
            model.form.calcAt = String(clip[timeR])
            model.persistSoon()
            model.toast = "Pasted DSPERFO"
        } else {
            model.alertMessage = "No DSPERFO take-off line on the clipboard."
        }
    }
}

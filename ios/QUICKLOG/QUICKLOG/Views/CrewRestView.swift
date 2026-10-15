import SwiftUI

struct CrewRestSheet: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let p = model.palette
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { model.showCrewRest = false }
            VStack(alignment: .leading, spacing: 10) {
                if model.crewTableOpen {
                    table
                } else {
                    setup
                }
            }
            .padding(16)
            .frame(maxWidth: 440)
            .background(p.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.line, lineWidth: 1))
        }
    }

    private var setup: some View {
        let p = model.palette
        let s = model.crewSuggestion
        return VStack(alignment: .leading, spacing: 10) {
            Text("CREW REST")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(p.text)
            Text(s.route.isEmpty ? "LOGBOOK DEPARTURE TIMES AND DEST WILL PREFILL FIELDS" : s.route)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(p.muted)
            Segmented(value: $model.crew.pattern, items: [(.rrr, "R R R"), (.twoR, "R R R 2R 2R 2R")])
                .onChange(of: model.crew.pattern) { _, _ in model.rescheduleCrewAlerts() }
            labeledClock("Timeframe start", text: $model.crew.start, derived: model.startDerived ? "derived from logbook" : nil)
            labeledClock("Timeframe end", text: $model.crew.end, derived: model.endDerived ? "derived from the block times table" : nil)
            HStack(alignment: .top) {
                Text("Changeover between rests")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(p.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    TextField("5", value: $model.crew.changeover, format: .number)
                        .keyboardType(.numberPad)
                        .padding(8)
                        .background(p.field)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.fieldBorder, lineWidth: 1))
                        .foregroundStyle(p.text)
                    Text("in minutes")
                        .font(.system(size: 10))
                        .foregroundStyle(p.muted)
                }
                .frame(width: 90)
            }
            if !model.crewPlan.hint.isEmpty {
                Text(model.crewPlan.hint).font(.system(size: 12, weight: .semibold)).foregroundStyle(p.warn)
            }
            HStack(spacing: 10) {
                QLButton(title: "Reset to default", kind: .muted, action: model.resetCrewDefaults)
                QLButton(title: "Time table", kind: .muted, action: model.showCrewTable)
            }
        }
    }

    private var table: some View {
        let p = model.palette
        let plan = model.crewPlan
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(plan.title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(p.text)
                Spacer()
                Toggle("PF at least two hours.", isOn: $model.crew.pfMin2h)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(p.muted)
                    .toggleStyle(.switch)
                    .onChange(of: model.crew.pfMin2h) { _, _ in model.rescheduleCrewAlerts() }
            }
            HStack {
                col("Rest", .leading)
                col("LENGTH", .center)
                col("START", .center)
                col("END", .center)
            }
            .foregroundStyle(p.accent)
            ForEach(plan.rows) { row in
                HStack {
                    Text(row.label).frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.length).frame(maxWidth: .infinity)
                    Text(row.start).frame(maxWidth: .infinity)
                    Text(row.end).frame(maxWidth: .infinity)
                }
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(p.text)
            }
            if !plan.hint.isEmpty {
                Text(plan.hint).font(.system(size: 12, weight: .semibold)).foregroundStyle(p.warn)
            }
            Toggle("Alert when each rest ends (works offline, even if the app is in the background).", isOn: $model.crew.alertAtEnd)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(p.muted)
                .onChange(of: model.crew.alertAtEnd) { _, _ in model.rescheduleCrewAlerts() }
            HStack(spacing: 10) {
                QLButton(title: "Copy / share as note", action: model.copyCrewNote)
                QLButton(title: "Edit", kind: .muted, action: { model.crewTableOpen = false })
            }
        }
    }

    private func col(_ t: String, _ a: Alignment) -> some View {
        Text(t).font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity, alignment: a)
    }

    private func labeledClock(_ title: String, text: Binding<String>, derived: String?) -> some View {
        let p = model.palette
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.text)
                if let derived {
                    Text(derived).font(.system(size: 10, weight: .medium)).foregroundStyle(p.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TextField("HH:MM", text: text)
                .keyboardType(.numberPad)
                .padding(8)
                .frame(width: 90)
                .background(p.field)
                .foregroundStyle(p.text)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.fieldBorder, lineWidth: 1))
                .onChange(of: text.wrappedValue) { _, raw in
                    let f = TimeMath.formatClock(TimeMath.digits(in: raw))
                    if f != raw { text.wrappedValue = f }
                    model.rescheduleCrewAlerts()
                }
        }
    }
}

struct PICSetupSheet: View {
    @EnvironmentObject var model: AppModel
    @State private var name = ""

    var body: some View {
        let p = model.palette
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text("Your default PIC name")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(p.text)
                TextField("Leave blank w/o default PIC", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(8)
                    .background(p.field)
                    .foregroundStyle(p.text)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("If you enter a name here, the PIC box will also default be ticked ON. Leave blank for no default PIC (typical for first officers).")
                    .font(.system(size: 11))
                    .foregroundStyle(p.muted)
                Text("Logbook is stored on this iPad and survives app updates.")
                    .font(.system(size: 11))
                    .foregroundStyle(p.muted)
                QLButton(title: "Save", action: { model.saveDefaultPIC(name) })
            }
            .padding(16)
            .frame(maxWidth: 420)
            .background(p.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onAppear { name = model.settings.defaultPIC }
    }
}

struct RemarkSheet: View {
    @EnvironmentObject var model: AppModel
    @State private var text = ""

    var body: some View {
        let p = model.palette
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text("Remark").font(.system(size: 16, weight: .bold)).foregroundStyle(p.text)
                TextEditor(text: $text)
                    .frame(minHeight: 80)
                    .padding(6)
                    .background(p.field)
                    .foregroundStyle(p.text)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Saved with this log line. Leave blank and Save to clear the remark.")
                    .font(.system(size: 11))
                    .foregroundStyle(p.muted)
                HStack {
                    QLButton(title: "Cancel", kind: .muted, action: { model.showRemark = false })
                    QLButton(title: "Save", action: {
                        model.form.logRemark = String(text.prefix(160))
                        model.showRemark = false
                        model.persistSoon()
                    })
                }
            }
            .padding(16)
            .frame(maxWidth: 420)
            .background(p.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onAppear { text = model.form.logRemark }
    }
}

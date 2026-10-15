import SwiftUI
import UIKit

struct Card<Content: View>: View {
    @EnvironmentObject var model: AppModel
    var padding: CGFloat = 10
    @ViewBuilder var content: () -> Content

    var body: some View {
        let p = model.palette
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(p.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(p.line, lineWidth: 1))
    }
}

struct FieldLabel: View {
    @EnvironmentObject var model: AppModel
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(model.palette.muted)
            .lineLimit(1)
    }
}

struct QLTextField: View {
    @EnvironmentObject var model: AppModel
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .characters
    var onChange: ((String) -> Void)? = nil

    var body: some View {
        let p = model.palette
        VStack(alignment: .leading, spacing: 3) {
            FieldLabel(text: label)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(autocap)
                .keyboardType(keyboard)
                .font(.system(size: 15, weight: .semibold, design: .default))
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(p.field)
                .foregroundStyle(p.text)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(p.fieldBorder, lineWidth: 1))
                .onChange(of: text) { _, new in
                    onChange?(new)
                    model.persistSoon()
                }
        }
    }
}

struct QLButton: View {
    @EnvironmentObject var model: AppModel
    let title: String
    var kind: Kind = .primary
    var action: () -> Void

    enum Kind { case primary, muted, warn }

    var body: some View {
        let p = model.palette
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.4)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 36)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(kind == .muted ? p.muted : (kind == .warn ? p.warn : p.btnText))
        .background(kind == .primary ? p.btn : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(kind == .warn ? p.warn : (kind == .muted ? p.line : Color.clear), lineWidth: 1)
        )
    }
}

struct Segmented<T: Hashable>: View {
    @EnvironmentObject var model: AppModel
    @Binding var value: T
    let items: [(T, String)]

    var body: some View {
        let p = model.palette
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                Button {
                    value = item.0
                } label: {
                    Text(item.1)
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .foregroundStyle(value == item.0 ? p.btnText : p.muted)
                        .background(value == item.0 ? p.btn : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(p.field)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(p.line, lineWidth: 1))
    }
}

struct ClockField: View {
    @EnvironmentObject var model: AppModel
    let label: String
    @Binding var text: String
    var placeholder: String = "HH:MM"
    var warn: Bool = false

    var body: some View {
        QLTextField(label: label, text: $text, placeholder: placeholder, keyboard: .numberPad, autocap: .never) { raw in
            let formatted = TimeMath.formatClock(TimeMath.digits(in: raw))
            if formatted != raw { text = formatted }
        }
        .environmentObject(model)
        .overlay(alignment: .trailing) {
            if warn {
                RoundedRectangle(cornerRadius: 8).stroke(model.palette.warn, lineWidth: 1.5).padding(.top, 16)
            }
        }
    }
}

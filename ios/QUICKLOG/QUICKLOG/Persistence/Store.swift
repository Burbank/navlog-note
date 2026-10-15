import Foundation

/// File-backed store. Survives app updates (unlike deleting a Home Screen PWA).
final class Store {
    static let shared = Store()
    static let logStoreMax = 60

    private let dir: URL
    private let formURL: URL
    private let logURL: URL
    private let settingsURL: URL

    struct Settings: Codable {
        var theme: ThemeMode = .system
        var defaultPIC: String = ""
        var askedPIC: Bool = false
        var extraAirports: [String] = []
        var recentPICNames: [String] = []
        var lastNonSimAircraft: String = "CKA"
        var lastNonSimDep: String = ""
        var lastNonSimArr: String = "AMS"
    }

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dir = base.appendingPathComponent("QUICKLOG", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        formURL = dir.appendingPathComponent("form.json")
        logURL = dir.appendingPathComponent("logbook.json")
        settingsURL = dir.appendingPathComponent("settings.json")
    }

    func loadForm() -> FormState {
        decode(formURL) ?? FormState()
    }

    func saveForm(_ form: FormState) {
        encode(form, to: formURL)
    }

    func loadLog() -> [LogLeg] {
        decode(logURL) ?? []
    }

    func saveLog(_ legs: [LogLeg]) {
        encode(Array(legs.prefix(Self.logStoreMax)), to: logURL)
    }

    func loadSettings() -> Settings {
        decode(settingsURL) ?? Settings()
    }

    func saveSettings(_ settings: Settings) {
        encode(settings, to: settingsURL)
    }

    private func decode<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, to url: URL) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}

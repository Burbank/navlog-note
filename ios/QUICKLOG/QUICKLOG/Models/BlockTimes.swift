import Foundation

enum BlockTimes {
    static let airports = ["ALA", "AMS", "BOG", "DWC", "GYD", "HHN", "HKG", "ICN", "JNB", "MIA", "NBO"]
    static let aircraft = ["CKA", "CKB", "CKC", "MPS", "SIM"]

    static let s26: [String: String] = [
        "ALA-AMS": "8:10", "AMS-DWC": "6:40", "AMS-HHN": "1:05", "AMS-HKG": "11:55",
        "AMS-ICN": "11:45", "AMS-JNB": "10:50", "AMS-MIA": "9:30", "BOG-MIA": "3:45",
        "DWC-AMS": "7:05", "DWC-HKG": "8:00", "GYD-AMS": "5:30", "HHN-AMS": "1:10",
        "HKG-ALA": "6:10", "HKG-GYD": "8:40", "HKG-DWC": "8:00", "ICN-HKG": "3:30",
        "JNB-NBO": "3:55", "MIA-AMS": "8:35", "MIA-BOG": "3:35", "NBO-AMS": "8:50"
    ]

    static let depToArr: [String: String] = [
        "MIA": "AMS", "NBO": "AMS", "JNB": "NBO", "GYD": "AMS", "HKG": "GYD",
        "ICN": "HKG", "AMS": "MIA", "BOG": "MIA", "HHN": "AMS"
    ]

    static let tzToDep: [String: String] = [
        "Europe/Amsterdam": "AMS", "Europe/Brussels": "AMS", "Europe/Luxembourg": "AMS",
        "Europe/Berlin": "HHN", "Asia/Almaty": "ALA", "America/Bogota": "BOG",
        "Asia/Dubai": "DWC", "Asia/Baku": "GYD", "Asia/Hong_Kong": "HKG",
        "Asia/Seoul": "ICN", "Africa/Johannesburg": "JNB", "America/New_York": "MIA",
        "America/Detroit": "MIA", "Africa/Nairobi": "NBO"
    ]

    static func block(dep: String, arr: String) -> String {
        guard !dep.isEmpty, !arr.isEmpty else { return "" }
        return s26["\(dep)-\(arr)"] ?? ""
    }

    static func detectDepAirport() -> String {
        let tz = TimeZone.current.identifier
        if let dep = tzToDep[tz] { return dep }
        let lower = tz.lowercased()
        let tokens: [(String, String)] = [
            ("amsterdam", "AMS"), ("brussels", "AMS"), ("berlin", "HHN"),
            ("frankfurt", "HHN"), ("almaty", "ALA"), ("bogota", "BOG"),
            ("dubai", "DWC"), ("baku", "GYD"), ("hong_kong", "HKG"),
            ("seoul", "ICN"), ("johannesburg", "JNB"), ("miami", "MIA"),
            ("new_york", "MIA"), ("nairobi", "NBO")
        ]
        for (token, code) in tokens where lower.contains(token) { return code }
        return "AMS"
    }

    static func defaultArr(for dep: String) -> String {
        depToArr[dep] ?? "AMS"
    }
}

import Foundation

enum AccountValidation {
    static func normalizedUsername(_ value: String) -> String {
        var clean = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while clean.hasPrefix("@") { clean.removeFirst() }
        return clean
    }

    static func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }

    static func isValidUsername(_ value: String) -> Bool {
        value.range(of: #"^[a-z0-9._]{3,20}$"#, options: .regularExpression) != nil
    }

    static func isStrongPassword(_ value: String) -> Bool {
        value.count >= 8 && value.rangeOfCharacter(from: .letters) != nil && value.rangeOfCharacter(from: .decimalDigits) != nil
    }

    static func normalizedWebsite(_ value: String) -> String? {
        let clean = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        guard !clean.isEmpty else { return "" }
        let lower = clean.lowercased()
        let candidate = lower.hasPrefix("https://") || lower.hasPrefix("http://") ? clean : "https://\(clean)"
        guard let components = URLComponents(string: candidate),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host?.contains(".") == true else { return nil }
        return candidate
    }
}

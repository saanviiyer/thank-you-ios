import CryptoKit
import Foundation
import Security

struct UserAccount: Codable, Equatable {
    let id: UUID
    var name: String
    var username: String
    var email: String
    var bio: String
    var location: String?
    var website: String?
    var avatarData: Data?
    var joinedAt: Date?
    var initials: String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
}

private struct StoredAccount: Codable {
    let user: UserAccount
    let passwordHash: String
    let salt: String?
}

private enum KeychainRead { case data(Data), notFound, failed }

enum AuthError: LocalizedError {
    case invalidName, invalidEmail, invalidUsername, invalidWebsite, weakPassword, usernameTaken, emailTaken, invalidCredentials, storageUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidName: "Enter your full name."
        case .invalidEmail: "Enter a valid email address."
        case .invalidUsername: "Use 3–20 letters, numbers, periods, or underscores."
        case .invalidWebsite: "Enter a valid website, such as example.com."
        case .weakPassword: "Use at least 8 characters with a letter and a number."
        case .usernameTaken: "That username is already taken on this device."
        case .emailTaken: "An account with that email already exists."
        case .invalidCredentials: "The email or password is incorrect."
        case .storageUnavailable: "Your secure account storage is unavailable. Try again after unlocking your device."
        }
    }
}

@MainActor final class AuthStore: ObservableObject {
    @Published private(set) var currentUser: UserAccount?
    @Published var errorMessage: String?
    private let accountsKey = "thankyou.accounts.v1"
    private let sessionKey = "thankyou.session.v1"
    private let keychainService = "com.thankyou.kindness.accounts"

    init() { restoreSession() }

    func signUp(name: String, username: String, email: String, password: String, bio: String = "") -> Bool {
        errorMessage = nil
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanUsername = AccountValidation.normalizedUsername(username)
        guard cleanName.count >= 2 else { return fail(.invalidName) }
        guard AccountValidation.isValidEmail(cleanEmail) else { return fail(.invalidEmail) }
        guard AccountValidation.isValidUsername(cleanUsername) else { return fail(.invalidUsername) }
        guard AccountValidation.isStrongPassword(password) else { return fail(.weakPassword) }
        guard var accounts = loadAccounts() else { return fail(.storageUnavailable) }
        guard !accounts.contains(where: { $0.user.email == cleanEmail }) else { return fail(.emailTaken) }
        guard !accounts.contains(where: { $0.user.username == cleanUsername }) else { return fail(.usernameTaken) }
        let cleanBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = UserAccount(id: UUID(), name: cleanName, username: cleanUsername, email: cleanEmail, bio: cleanBio.isEmpty ? "Trying to leave things a little better than I found them." : cleanBio, joinedAt: Date())
        let salt = UUID().uuidString
        accounts.append(StoredAccount(user: user, passwordHash: hash(password, salt: salt), salt: salt))
        guard save(accounts) else { return fail(.storageUnavailable) }
        startSession(user); return true
    }

    func signIn(email: String, password: String) -> Bool {
        errorMessage = nil
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let accounts = loadAccounts() else { return fail(.storageUnavailable) }
        guard let match = accounts.first(where: { $0.user.email == cleanEmail && $0.passwordHash == hash(password, salt: $0.salt ?? "") }) else { return fail(.invalidCredentials) }
        startSession(match.user); return true
    }

    func updateProfile(name: String, username: String, bio: String, location: String, website: String, avatarData: Data?) -> Bool {
        errorMessage = nil
        guard var user = currentUser else { return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = AccountValidation.normalizedUsername(username)
        guard cleanName.count >= 2 else { return fail(.invalidName) }
        guard AccountValidation.isValidUsername(cleanUsername) else { return fail(.invalidUsername) }
        guard var accounts = loadAccounts() else { return fail(.storageUnavailable) }
        guard !accounts.contains(where: { $0.user.id != user.id && $0.user.username == cleanUsername }) else { return fail(.usernameTaken) }
        user.name = cleanName
        user.username = cleanUsername
        user.bio = String(bio.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        user.location = String(location.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard let cleanWebsite = AccountValidation.normalizedWebsite(website) else { return fail(.invalidWebsite) }
        user.website = cleanWebsite
        user.avatarData = avatarData
        if let index = accounts.firstIndex(where: { $0.user.id == user.id }) {
            accounts[index] = StoredAccount(user: user, passwordHash: accounts[index].passwordHash, salt: accounts[index].salt)
            guard save(accounts) else { return fail(.storageUnavailable) }
            startSession(user)
            return true
        }
        return false
    }

    func deleteCurrentAccount() -> Bool {
        guard let user = currentUser, let accounts = loadAccounts() else { return fail(.storageUnavailable) }
        guard save(accounts.filter { $0.user.id != user.id }) else { return fail(.storageUnavailable) }
        signOut()
        return true
    }

    func signOut() { currentUser = nil; UserDefaults.standard.removeObject(forKey: sessionKey) }
    private func startSession(_ user: UserAccount) { currentUser = user; UserDefaults.standard.set(user.id.uuidString, forKey: sessionKey) }
    private func restoreSession() {
        guard let rawID = UserDefaults.standard.string(forKey: sessionKey), let id = UUID(uuidString: rawID) else { return }
        guard let accounts = loadAccounts() else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
            errorMessage = AuthError.storageUnavailable.localizedDescription
            return
        }
        currentUser = accounts.first(where: { $0.user.id == id })?.user
        if currentUser == nil { UserDefaults.standard.removeObject(forKey: sessionKey) }
    }
    private func loadAccounts() -> [StoredAccount]? {
        switch keychainData() {
        case .data(let data):
            return try? JSONDecoder().decode([StoredAccount].self, from: data)
        case .failed:
            return nil
        case .notFound:
            break
        }
        guard let legacy = UserDefaults.standard.data(forKey: accountsKey),
              let accounts = try? JSONDecoder().decode([StoredAccount].self, from: legacy) else { return [] }
        guard save(accounts) else { return nil }
        UserDefaults.standard.removeObject(forKey: accountsKey)
        return accounts
    }
    @discardableResult private func save(_ accounts: [StoredAccount]) -> Bool {
        guard let data = try? JSONEncoder().encode(accounts) else { return false }
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: accountsKey
        ]
        let status = SecItemUpdate(lookup as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound {
            var item = lookup
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        }
        return false
    }
    private func keychainData() -> KeychainRead {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: accountsKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return .notFound }
        guard status == errSecSuccess, let data = result as? Data else { return .failed }
        return .data(data)
    }
    private func hash(_ password: String, salt: String) -> String { SHA256.hash(data: Data((salt + password).utf8)).map { String(format: "%02x", $0) }.joined() }
    private func fail(_ error: AuthError) -> Bool { errorMessage = error.localizedDescription; return false }
}

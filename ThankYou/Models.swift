import Foundation
import SwiftUI

struct KindnessPost: Identifiable, Hashable {
    let id: UUID
    let author: Person
    let time: String
    let message: String
    let category: KindnessCategory
    var thanks: Int
    let comments: Int
    var replies: [KindnessComment]
    var isThanked: Bool
    let featured: Bool
    let artwork: Artwork?
    let imageData: Data?
    let place: Place?

    init(id: UUID = UUID(), author: Person, time: String, message: String, category: KindnessCategory, thanks: Int, comments: Int, replies: [KindnessComment] = [], isThanked: Bool = false, featured: Bool = false, artwork: Artwork? = nil, imageData: Data? = nil, place: Place? = nil) {
        self.id = id; self.author = author; self.time = time; self.message = message
        self.category = category; self.thanks = thanks; self.comments = comments; self.replies = replies
        self.isThanked = isThanked; self.featured = featured; self.artwork = artwork; self.imageData = imageData; self.place = place
    }

    var commentCount: Int { comments + replies.count }
}

struct Person: Identifiable, Hashable {
    var id: String { handle.lowercased() }
    let name: String
    let handle: String
    let initials: String
    let color: Color
    let avatarData: Data?

    init(name: String, handle: String, initials: String, color: Color, avatarData: Data? = nil) {
        self.name = name
        self.handle = handle
        self.initials = initials
        self.color = color
        self.avatarData = avatarData
    }
}

struct KindnessComment: Identifiable, Hashable, Codable {
    let id: UUID
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let body: String
    let createdAt: Date

    init(id: UUID = UUID(), author: Person, body: String, createdAt: Date = Date()) {
        self.id = id
        authorName = author.name
        authorHandle = author.handle
        authorInitials = author.initials
        self.body = body
        self.createdAt = createdAt
    }
}

struct ActivityItem: Identifiable, Hashable, Codable {
    enum Kind: String, Codable { case thanks, follow, comment, welcome, post }
    let id: UUID
    let kind: Kind
    let message: String
    let createdAt: Date
    var isRead: Bool

    init(id: UUID = UUID(), kind: Kind, message: String, createdAt: Date = Date(), isRead: Bool = false) {
        self.id = id; self.kind = kind; self.message = message; self.createdAt = createdAt; self.isRead = isRead
    }
}

enum KindnessCategory: String, CaseIterable, Hashable, Codable {
    case everyday = "Everyday kindness"
    case gratitude = "A thank you"
    case neighbor = "Neighbor love"
    case planet = "For the planet"
    case extra = "Small act, big day"

    var symbol: String {
        switch self {
        case .everyday: "sparkles"
        case .gratitude: "heart.fill"
        case .neighbor: "person.2.fill"
        case .planet: "leaf.fill"
        case .extra: "sun.max.fill"
        }
    }
}

enum Artwork: Hashable { case garden }

struct Place: Hashable, Codable {
    let name: String
    let locality: String
    let latitude: Double
    let longitude: Double
}

@MainActor
final class KindnessStore: ObservableObject {
    @Published var posts: [KindnessPost]
    @Published var following: Set<String>
    @Published var activity: [ActivityItem]
    @Published private(set) var storageError: String?
    private let legacyStateKey = "thankyou.kindness-state.v1"
    private var activeUserKey: String?
    private var activeHandle: String?
    private var userStates: [String: StoredUserState] = [:]
    private var pendingLegacyUserState: StoredUserState?

    private var stateURL: URL? { URL.applicationSupportDirectory.appending(path: "kindness-state-v2.json") }

    init() {
        if let url = stateURL,
           let data = try? Data(contentsOf: url),
           let state = try? JSONDecoder().decode(StoredKindnessStateV2.self, from: data),
           state.version == 2 {
            posts = state.posts.map(KindnessPost.init(stored:))
            userStates = state.users
            following = []
            activity = []
        } else if let data = UserDefaults.standard.data(forKey: legacyStateKey),
           let state = try? JSONDecoder().decode(StoredKindnessState.self, from: data) {
            posts = state.posts.map(KindnessPost.init(stored:))
            following = []
            activity = []
            pendingLegacyUserState = StoredUserState(
                following: state.following,
                thankedPostIDs: state.posts.filter(\.isThanked).map(\.id),
                activity: state.activity ?? []
            )
        } else {
            posts = SampleData.posts
            following = []
            activity = []
        }
        for index in posts.indices { posts[index].isThanked = false }
    }

    func activate(userID: UUID, handle: String) {
        let key = userID.uuidString
        activeUserKey = key
        activeHandle = handle
        if userStates[key] == nil {
            userStates[key] = pendingLegacyUserState ?? StoredUserState(
                following: [],
                thankedPostIDs: [],
                activity: [ActivityItem(kind: .welcome, message: "Welcome to thank you. Your kindness feed is ready.")]
            )
            pendingLegacyUserState = nil
        }
        var state = userStates[key]!
        state.following.removeAll { $0 == handle }
        userStates[key] = state
        following = Set(state.following)
        activity = state.activity
        let thanked = Set(state.thankedPostIDs)
        for index in posts.indices { posts[index].isThanked = thanked.contains(posts[index].id) }
        persist()
    }

    func toggleThanks(_ post: KindnessPost) {
        guard let key = activeUserKey,
              var state = userStates[key],
              let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].isThanked.toggle()
        posts[index].thanks = max(0, posts[index].thanks + (posts[index].isThanked ? 1 : -1))
        if posts[index].isThanked { state.thankedPostIDs.append(post.id) }
        else { state.thankedPostIDs.removeAll { $0 == post.id } }
        state.thankedPostIDs = Array(Set(state.thankedPostIDs))
        userStates[key] = state
        persist()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func addPost(message: String, category: KindnessCategory, imageData: Data?, place: Place?, author: Person) {
        let clean = String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))
        guard !clean.isEmpty else { return }
        posts.insert(KindnessPost(author: author, time: "now", message: clean, category: category, thanks: 0, comments: 0, imageData: imageData, place: place), at: 0)
        activity.insert(ActivityItem(kind: .post, message: "Your story was shared."), at: 0)
        syncActiveState()
        persist()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func toggleFollow(_ person: Person) {
        guard activeUserKey != nil, person.handle != activeHandle else { return }
        if following.contains(person.handle) {
            following.remove(person.handle)
        } else {
            following.insert(person.handle)
            activity.insert(ActivityItem(kind: .follow, message: "You followed \(person.name)."), at: 0)
        }
        syncActiveState()
        persist()
    }

    func addComment(to postID: UUID, body: String, author: Person) {
        let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].replies.append(KindnessComment(author: author, body: String(clean.prefix(500))))
        activity.insert(ActivityItem(kind: .comment, message: "You replied to \(posts[index].author.name)."), at: 0)
        syncActiveState()
        persist()
    }

    func deletePost(_ postID: UUID, authoredBy handle: String) {
        posts.removeAll { $0.id == postID && $0.author.handle == handle }
        for key in userStates.keys {
            userStates[key]?.thankedPostIDs.removeAll { $0 == postID }
        }
        persist()
    }

    func updateAuthor(previousHandle: String, person: Person) {
        for index in posts.indices where posts[index].author.handle == previousHandle {
            posts[index] = KindnessPost(
                id: posts[index].id,
                author: person,
                time: posts[index].time,
                message: posts[index].message,
                category: posts[index].category,
                thanks: posts[index].thanks,
                comments: posts[index].comments,
                replies: posts[index].replies,
                isThanked: posts[index].isThanked,
                featured: posts[index].featured,
                artwork: posts[index].artwork,
                imageData: posts[index].imageData,
                place: posts[index].place
            )
        }
        for postIndex in posts.indices {
            posts[postIndex].replies = posts[postIndex].replies.map { comment in
                guard comment.authorHandle == previousHandle else { return comment }
                return KindnessComment(id: comment.id, author: person, body: comment.body, createdAt: comment.createdAt)
            }
        }
        for key in userStates.keys {
            guard var state = userStates[key] else { continue }
            state.following = Array(Set(state.following.map { $0 == previousHandle ? person.handle : $0 })).sorted()
            userStates[key] = state
        }
        following = Set(following.map { $0 == previousHandle ? person.handle : $0 })
        if activeHandle == previousHandle { activeHandle = person.handle }
        persist()
    }

    func deleteAccountData(userID: UUID, handle: String) {
        let key = userID.uuidString
        userStates.removeValue(forKey: key)
        let removedPostIDs = Set(posts.filter { $0.author.handle == handle }.map(\.id))
        posts.removeAll { $0.author.handle == handle }
        for index in posts.indices { posts[index].replies.removeAll { $0.authorHandle == handle } }
        for stateKey in userStates.keys {
            userStates[stateKey]?.following.removeAll { $0 == handle }
            userStates[stateKey]?.thankedPostIDs.removeAll { removedPostIDs.contains($0) }
        }
        if activeUserKey == key {
            activeUserKey = nil
            activeHandle = nil
            following = []
            activity = []
        }
        persist()
    }

    func markActivityRead() {
        for index in activity.indices { activity[index].isRead = true }
        syncActiveState()
        persist()
    }

    var unreadActivityCount: Int { activity.filter { !$0.isRead }.count }

    private func syncActiveState() {
        guard let key = activeUserKey, var state = userStates[key] else { return }
        state.following = Array(following).sorted()
        state.activity = activity
        userStates[key] = state
    }

    private func persist() {
        syncActiveState()
        guard let url = stateURL else {
            storageError = "Stories could not be saved on this device."
            return
        }
        do {
            let state = StoredKindnessStateV2(version: 2, posts: posts.map(StoredKindnessPost.init), users: userStates)
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            UserDefaults.standard.removeObject(forKey: legacyStateKey)
            storageError = nil
        } catch {
            storageError = "Your latest change could not be saved. Check available device storage."
        }
    }
}

private struct StoredKindnessStateV2: Codable {
    let version: Int
    let posts: [StoredKindnessPost]
    let users: [String: StoredUserState]
}

private struct StoredUserState: Codable {
    var following: [String]
    var thankedPostIDs: [UUID]
    var activity: [ActivityItem]
}

private struct StoredKindnessState: Codable {
    let posts: [StoredKindnessPost]
    let following: [String]
    let activity: [ActivityItem]?
}

private struct StoredKindnessPost: Codable {
    let id: UUID
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let authorAvatarData: Data?
    let time: String
    let message: String
    let category: KindnessCategory
    let thanks: Int
    let comments: Int
    let replies: [KindnessComment]?
    let isThanked: Bool
    let featured: Bool
    let artwork: String?
    let imageData: Data?
    let place: Place?

    init(_ post: KindnessPost) {
        id = post.id
        authorName = post.author.name
        authorHandle = post.author.handle
        authorInitials = post.author.initials
        authorAvatarData = post.author.avatarData
        time = post.time
        message = post.message
        category = post.category
        thanks = post.thanks
        comments = post.comments
        replies = post.replies
        isThanked = post.isThanked
        featured = post.featured
        artwork = post.artwork == .garden ? "garden" : nil
        imageData = post.imageData
        place = post.place
    }
}

private extension KindnessPost {
    init(stored: StoredKindnessPost) {
        let color: Color = switch stored.authorHandle {
        case "@mayac": .kindCoral
        case "@elithompson": .kindBlue
        case "@nadiap": .kindViolet
        case "@jonb": .kindGreen
        default: .kindOrange
        }
        self.init(
            id: stored.id,
            author: Person(name: stored.authorName, handle: stored.authorHandle, initials: stored.authorInitials, color: color, avatarData: stored.authorAvatarData),
            time: stored.time,
            message: stored.message,
            category: stored.category,
            thanks: stored.thanks,
            comments: stored.comments,
            replies: stored.replies ?? [],
            isThanked: stored.isThanked,
            featured: stored.featured,
            artwork: stored.artwork == "garden" ? .garden : nil,
            imageData: stored.imageData,
            place: stored.place
        )
    }
}

enum SampleData {
    static let people = [
        Person(name: "Sam Rivera", handle: "@samrivera", initials: "SR", color: .kindAmber),
        Person(name: "Leila Moore", handle: "@leilam", initials: "LM", color: .kindPink),
        Person(name: "Theo Park", handle: "@theopark", initials: "TP", color: .kindTeal)
    ]

    static let posts = [
        KindnessPost(author: Person(name: "Maya Chen", handle: "@mayac", initials: "MC", color: .kindCoral), time: "12m", message: "Saw someone leave their umbrella on the train this morning. Ran two blocks in the rain to catch up with them. We both ended up soaked and laughing.", category: .extra, thanks: 84, comments: 7, featured: true, place: Place(name: "Caltrain Station", locality: "Palo Alto, CA", latitude: 37.443, longitude: -122.165)),
        KindnessPost(author: Person(name: "Eli Thompson", handle: "@elithompson", initials: "ET", color: .kindBlue), time: "38m", message: "My neighbor Mr. Flores has been teaching me how to grow tomatoes. Today I brought over the first loaf of sourdough I didn’t mess up. A pretty great trade, if you ask me.", category: .neighbor, thanks: 126, comments: 14, artwork: .garden, place: Place(name: "Johnson Community Garden", locality: "Pasadena, CA", latitude: 34.147, longitude: -118.144)),
        KindnessPost(author: Person(name: "Nadia Patel", handle: "@nadiap", initials: "NP", color: .kindViolet), time: "1h", message: "To the barista who remembered my order on a hard morning — you had no idea, but that tiny bit of care meant everything. Thank you, June. ☕️", category: .gratitude, thanks: 203, comments: 21),
        KindnessPost(author: Person(name: "Jon Bell", handle: "@jonb", initials: "JB", color: .kindGreen), time: "2h", message: "Spent the afternoon picking up trash along our favorite trail with twelve complete strangers. We arrived alone and left with a group chat.", category: .planet, thanks: 67, comments: 5)
    ]
}

extension Color {
    static let kindBackground = Color(red: 0.985, green: 0.978, blue: 0.957)
    static let kindCream = Color(red: 0.957, green: 0.925, blue: 0.866)
    static let kindCoral = Color(red: 0.925, green: 0.408, blue: 0.306)
    static let kindInk = Color(red: 0.13, green: 0.125, blue: 0.115)
    static let kindMuted = Color(red: 0.47, green: 0.45, blue: 0.42)
    static let kindOrange = Color(red: 0.82, green: 0.46, blue: 0.28)
    static let kindAmber = Color(red: 0.70, green: 0.48, blue: 0.26)
    static let kindPink = Color(red: 0.72, green: 0.39, blue: 0.47)
    static let kindTeal = Color(red: 0.30, green: 0.55, blue: 0.56)
    static let kindBlue = Color(red: 0.32, green: 0.50, blue: 0.63)
    static let kindViolet = Color(red: 0.51, green: 0.43, blue: 0.60)
    static let kindGreen = Color(red: 0.38, green: 0.54, blue: 0.42)
}

extension UserAccount {
    var person: Person {
        Person(name: name, handle: "@\(username)", initials: initials, color: .kindOrange, avatarData: avatarData)
    }
}

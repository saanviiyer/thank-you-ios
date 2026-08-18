import SwiftUI
@preconcurrency import PhotosUI

struct ComposerView: View {
    @EnvironmentObject private var store: KindnessStore
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var category: KindnessCategory = .everyday
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var mediaError: String?
    @StateObject private var location = LocationManager()

    var body: some View {
        let photoButtonTitle = imageData == nil ? "Add photo" : "Change photo"
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Label("SHARE THE GOOD", systemImage: "sparkles").font(.caption.bold()).tracking(1.4).foregroundStyle(Color.kindCoral)
                Text("What kind thing happened?").font(.system(size: 30, weight: .bold, design: .serif))
                HStack(alignment: .top, spacing: 13) {
                    Avatar(person: currentPerson)
                    TextEditor(text: $message).font(.system(size: 19, design: .serif)).scrollContentBackground(.hidden)
                        .frame(minHeight: 180).overlay(alignment: .topLeading) {
                            if message.isEmpty { Text("Share a kind act, or thank someone who made your day...").font(.system(size: 19, design: .serif)).foregroundStyle(.tertiary).allowsHitTesting(false).padding(.top, 8).padding(.leading, 5) }
                        }
                }
                if let data = imageData, let image = UIImage(data: data) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 14)).clipped()
                        Button { imageData = nil; selectedPhoto = nil } label: { Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(.white).padding(9).background(.black.opacity(0.65), in: Circle()) }.padding(10)
                    }
                }
                if let place = location.place {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(Color.kindCoral)
                        VStack(alignment: .leading) { Text(place.name).font(.subheadline.bold()); Text(place.locality).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                        Spacer(); Button { location.place = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }.padding(13).background(Color.kindCream, in: RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) { Label(photoButtonTitle, systemImage: "photo").attachmentButton() }
                    Button { location.requestLocation() } label: { Label(location.isLocating ? "Locating…" : "Add location", systemImage: "location").attachmentButton() }.disabled(location.isLocating)
                }
                if let error = location.errorMessage ?? mediaError { Text(error).font(.caption).foregroundStyle(.red).accessibilityLabel("Error: \(error)") }
                Picker("Kindness type", selection: $category) {
                    ForEach(KindnessCategory.allCases, id: \.self) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                }
                Spacer()
                HStack { Text("\(message.count)/280").font(.caption).foregroundStyle(.secondary); Spacer() }
            }
            .padding(22).background(Color.kindBackground)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    guard let data = try? await newValue?.loadTransferable(type: Data.self),
                          let processed = ImageProcessor.compressedJPEG(from: data, maxDimension: 1_600, maxBytes: 4_000_000) else {
                        mediaError = "That photo could not be prepared. Choose a different image."
                        return
                    }
                    imageData = processed
                    mediaError = nil
                }
            }
            .navigationTitle("New story").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { store.addPost(message: message, category: category, imageData: imageData, place: location.place, author: currentPerson); dismiss() }
                        .fontWeight(.bold).disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.count > 280)
                }
            }
        }
    }

    private var currentPerson: Person { auth.currentUser?.person ?? Person(name: "Alex Morgan", handle: "@alexm", initials: "AM", color: .kindOrange) }
}

struct DiscoverView: View {
    @EnvironmentObject private var store: KindnessStore
    @State private var search = ""
    var filtered: [KindnessPost] { search.isEmpty ? store.posts : store.posts.filter { $0.message.localizedCaseInsensitiveContains(search) || $0.author.name.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Good is everywhere.").font(.system(size: 32, weight: .bold, design: .serif)).padding(20)
                    Text("PEOPLE TO FOLLOW").font(.caption2.bold()).tracking(1.4).padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SampleData.people) { person in PersonSuggestion(person: person) }
                        }.padding(.horizontal, 20).padding(.vertical, 12)
                    }
                    ForEach(filtered) { PostCard(post: $0) }
                }
            }.background(Color.kindBackground).navigationTitle("Discover").searchable(text: $search, prompt: "Search kindness")
        }
    }
}

struct NotificationsView: View {
    @EnvironmentObject private var store: KindnessStore
    var body: some View {
        NavigationStack {
            List(store.activity) { item in
                HStack(spacing: 14) {
                    Image(systemName: symbol(for: item.kind)).foregroundStyle(.white).frame(width: 38, height: 38).background(color(for: item.kind), in: Circle())
                    VStack(alignment: .leading) { Text(item.message).font(.subheadline.weight(.medium)); Text(item.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary) }
                }.padding(.vertical, 6).listRowBackground(Color.kindBackground)
            }
            .overlay { if store.activity.isEmpty { ContentUnavailableView("No activity yet", systemImage: "bell", description: Text("Follows, replies, and shared stories appear here.")) } }
            .scrollContentBackground(.hidden).background(Color.kindBackground).navigationTitle("Activity")
            .onAppear { store.markActivityRead() }
        }
    }

    private func symbol(for kind: ActivityItem.Kind) -> String {
        switch kind { case .thanks: "heart.fill"; case .follow: "person.crop.circle.badge.plus"; case .comment: "bubble.left.fill"; case .welcome: "sparkles"; case .post: "checkmark.circle.fill" }
    }
    private func color(for kind: ActivityItem.Kind) -> Color {
        switch kind { case .thanks: .kindCoral; case .follow: .kindBlue; case .comment: .kindAmber; case .welcome: .kindViolet; case .post: .kindGreen }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: KindnessStore
    @EnvironmentObject private var auth: AuthStore
    @State private var editing = false
    @State private var confirmingDelete = false
    var me: Person { auth.currentUser?.person ?? Person(name: "Alex Morgan", handle: "@alexm", initials: "AM", color: .kindOrange) }
    var myPosts: [KindnessPost] { store.posts.filter { $0.author.handle == me.handle } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Avatar(person: me, size: 82)
                    VStack(spacing: 3) { Text(me.name).font(.title2.bold()); Text(me.handle).foregroundStyle(.secondary) }
                    Text(auth.currentUser?.bio ?? "Trying to leave things a little better than I found them.").font(.subheadline).multilineTextAlignment(.center)
                    if let location = auth.currentUser?.location, !location.isEmpty { Label(location, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary) }
                    if let website = auth.currentUser?.website, !website.isEmpty, let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") { Link(website, destination: url).font(.caption) }
                    HStack(spacing: 35) {
                        Stat(value: "\(myPosts.count)", label: "stories"); Stat(value: "\(myPosts.reduce(0) { $0 + $1.thanks })", label: "thanks"); Stat(value: "\(store.following.count)", label: "following")
                    }.padding(.vertical, 8)
                    Divider()
                    Text("YOUR KINDNESS").font(.caption2.bold()).tracking(1.5).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(myPosts) { PostCard(post: $0) }
                    if myPosts.isEmpty {
                        ContentUnavailableView("Your good starts here", systemImage: "heart", description: Text("Share your first story of kindness."))
                    }
                    VStack(spacing: 10) {
                        Button { auth.signOut() } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                        Button(role: .destructive) { confirmingDelete = true } label: { Text("Delete account").font(.caption) }
                    }.padding(.horizontal, 20).padding(.vertical, 15)
                }.padding(.top, 25)
            }.background(Color.kindBackground).navigationTitle("Profile")
                .toolbar { Button("Edit") { editing = true } }
                .sheet(isPresented: $editing) { EditProfileView() }
                .confirmationDialog("Delete this account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete account", role: .destructive) {
                        guard let user = auth.currentUser else { return }
                        if auth.deleteCurrentAccount() {
                            store.deleteAccountData(userID: user.id, handle: user.person.handle)
                        }
                    }
                } message: { Text("Your sign-in, profile, stories, replies, and social activity will be permanently removed from this device.") }
        }
    }
}

struct PersonSuggestion: View {
    @EnvironmentObject private var store: KindnessStore
    @EnvironmentObject private var auth: AuthStore
    let person: Person
    var body: some View {
        VStack(spacing: 8) {
            Avatar(person: person, size: 52)
            Text(person.name).font(.caption.bold()).lineLimit(1)
            if person.handle == auth.currentUser?.person.handle {
                Text("You").font(.caption.bold()).foregroundStyle(.secondary).padding(.vertical, 7)
            } else {
                Button(store.following.contains(person.handle) ? "Following" : "Follow") { store.toggleFollow(person) }
                    .font(.caption.bold()).buttonStyle(.borderedProminent).tint(store.following.contains(person.handle) ? .gray : .kindCoral)
            }
        }.frame(width: 110).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct PersonProfileView: View {
    @EnvironmentObject private var store: KindnessStore
    @EnvironmentObject private var auth: AuthStore
    let person: Person
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Avatar(person: person, size: 86)
                Text(person.name).font(.title2.bold())
                Text(person.handle).foregroundStyle(.secondary)
                if person.handle != auth.currentUser?.person.handle {
                    Button(store.following.contains(person.handle) ? "Following" : "Follow") { store.toggleFollow(person) }
                        .buttonStyle(.borderedProminent).tint(store.following.contains(person.handle) ? .gray : .kindCoral)
                }
                Divider()
                ForEach(store.posts.filter { $0.author.handle == person.handle }) { PostCard(post: $0) }
            }.padding(.top, 24)
        }.background(Color.kindBackground).navigationTitle(person.name).navigationBarTitleDisplayMode(.inline)
    }
}

struct CommentsView: View {
    @EnvironmentObject private var store: KindnessStore
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var reply = ""
    private var post: KindnessPost? { store.posts.first { $0.id == postID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    if let count = post?.comments, count > 0 { Text("\(count) earlier replies").font(.caption).foregroundStyle(.secondary) }
                    ForEach(post?.replies ?? []) { comment in
                        HStack(alignment: .top, spacing: 10) {
                            Avatar(person: Person(name: comment.authorName, handle: comment.authorHandle, initials: comment.authorInitials, color: .kindOrange), size: 36)
                            VStack(alignment: .leading, spacing: 3) { Text(comment.authorName).font(.subheadline.bold()); Text(comment.body); Text(comment.createdAt, style: .relative).font(.caption2).foregroundStyle(.secondary) }
                        }.padding(.vertical, 4)
                    }
                }.listStyle(.plain)
                HStack(spacing: 10) {
                    TextField("Write a kind reply…", text: $reply, axis: .vertical).lineLimit(1...4).padding(11).background(Color.kindCream, in: RoundedRectangle(cornerRadius: 12))
                    Button { if let person = auth.currentUser?.person { store.addComment(to: postID, body: reply, author: person); reply = "" } } label: { Image(systemName: "arrow.up").fontWeight(.bold).foregroundStyle(.white).padding(11).background(Color.kindCoral, in: Circle()) }.disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding()
            }.navigationTitle("Replies").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var store: KindnessStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var website = ""
    @State private var avatarData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var mediaError: String?

    var body: some View {
        let photoButtonTitle = avatarData == nil ? "Choose profile photo" : "Change profile photo"
        NavigationStack {
            Form {
                Section {
                    HStack { Spacer(); Avatar(person: Person(name: name, handle: "@\(username)", initials: initials, color: .kindOrange, avatarData: avatarData), size: 92); Spacer() }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) { Label(photoButtonTitle, systemImage: "photo") }
                    if avatarData != nil { Button("Remove photo", role: .destructive) { avatarData = nil; selectedPhoto = nil } }
                }
                Section("Profile") {
                    TextField("Name", text: $name).textContentType(.name)
                    TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Bio", text: $bio, axis: .vertical).lineLimit(3...6)
                    TextField("Location", text: $location)
                    TextField("Website", text: $website).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                if let error = auth.errorMessage ?? mediaError { Section { Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red) } }
            }
            .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.fontWeight(.bold) }
            }
            .onAppear {
                guard let user = auth.currentUser else { return }
                name = user.name; username = user.username; bio = user.bio; location = user.location ?? ""; website = user.website ?? ""; avatarData = user.avatarData
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let processed = ImageProcessor.compressedJPEG(from: data, maxDimension: 512, maxBytes: 1_000_000) else {
                        mediaError = "That profile photo could not be prepared."
                        return
                    }
                    avatarData = processed
                    mediaError = nil
                }
            }
        }
    }

    private var initials: String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
    private func save() {
        let previousHandle = auth.currentUser?.person.handle ?? ""
        if auth.updateProfile(name: name, username: username, bio: bio, location: location, website: website, avatarData: avatarData), let person = auth.currentUser?.person {
            store.updateAuthor(previousHandle: previousHandle, person: person)
            dismiss()
        }
    }
}

private extension View {
    nonisolated func attachmentButton() -> some View { self.font(.subheadline.weight(.semibold)).foregroundStyle(Color.kindCoral).padding(.horizontal, 13).padding(.vertical, 10).background(Color.kindCream, in: Capsule()) }
}

struct Stat: View {
    let value: String; let label: String
    var body: some View { VStack(spacing: 2) { Text(value).font(.headline); Text(label).font(.caption).foregroundStyle(.secondary) } }
}

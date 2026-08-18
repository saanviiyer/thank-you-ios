import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: KindnessStore
    @State private var selectedTab = 0
    @State private var showingComposer = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showingComposer: $showingComposer)
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "safari") }.tag(1)
            NotificationsView()
                .tabItem { Label("Activity", systemImage: "bell") }.badge(store.unreadActivityCount).tag(2)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }.tag(3)
        }
        .safeAreaInset(edge: .top) {
            if let error = store.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .sheet(isPresented: $showingComposer) { ComposerView() }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: KindnessStore
    @Binding var showingComposer: Bool
    @State private var feed = "For you"

    private var visiblePosts: [KindnessPost] {
        feed == "Following" ? store.posts.filter { store.following.contains($0.author.handle) } : store.posts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    HeroView()
                    HStack {
                        Text("THE KINDNESS FEED").tracking(1.4).font(.caption2.bold())
                        Spacer()
                        Text("\(store.posts.count) stories today").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 17)
                    ForEach(visiblePosts) { post in PostCard(post: post) }
                    if visiblePosts.isEmpty {
                        ContentUnavailableView("Your following feed is quiet", systemImage: "person.2", description: Text("Follow people from Discover to see their stories here."))
                            .padding(.vertical, 50)
                    }
                }
            }
            .background(Color.kindBackground)
            .navigationTitle("thank you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { HeartLogo(size: 30) }
                ToolbarItem(placement: .principal) {
                    Picker("Feed", selection: $feed) {
                        Text("For you").tag("For you")
                        Text("Following").tag("Following")
                    }.pickerStyle(.segmented).frame(width: 190)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingComposer = true } label: {
                        Image(systemName: "plus").fontWeight(.bold).frame(width: 30, height: 30)
                            .foregroundStyle(.white).background(Color.kindCoral, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
        }
    }
}

struct HeroView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 9) {
                Label("TODAY'S GOOD", systemImage: "sparkles").font(.caption2.bold()).tracking(1.4).foregroundStyle(Color.kindCoral)
                Text("Kindness looks good\non everyone.").font(.system(size: 32, weight: .bold, design: .serif)).foregroundStyle(Color.kindInk)
                Text("Share a little good. Make someone's day.").font(.subheadline).foregroundStyle(Color.kindMuted)
            }
            Spacer(minLength: 8)
            ZStack {
                Circle().fill(Color.kindCoral.opacity(0.16)).frame(width: 96, height: 96)
                HeartLogo(size: 66)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 30)
        .background(Color.kindCream)
    }
}

struct PostCard: View {
    @EnvironmentObject private var store: KindnessStore
    @EnvironmentObject private var auth: AuthStore
    let post: KindnessPost
    @State private var showingComments = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if post.featured {
                Label("A LITTLE EXTRA GOOD", systemImage: "sparkles")
                    .font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.brown)
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Color.kindCream, in: Capsule())
            }
            HStack(spacing: 11) {
                NavigationLink { PersonProfileView(person: post.author) } label: {
                    HStack(spacing: 11) {
                        Avatar(person: post.author)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.author.name).font(.subheadline.bold()).foregroundStyle(Color.kindInk)
                            Text("\(post.author.handle)  ·  \(post.time)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.buttonStyle(.plain)
                Spacer()
                if post.author.handle == auth.currentUser?.person.handle {
                    Menu {
                        Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete story", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary) }
                }
            }
            Text(post.message).font(.system(size: 18, weight: .regular, design: .serif)).lineSpacing(4)
            if let place = post.place {
                HStack(spacing: 7) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.kindCoral)
                    VStack(alignment: .leading, spacing: 1) { Text(place.name).font(.caption.bold()); Text(place.locality).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
            }
            if let data = post.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 12)).clipped()
            }
            if post.artwork == .garden { GardenArtwork() }
            Label(post.category.rawValue, systemImage: post.category.symbol)
                .font(.caption2.bold()).foregroundStyle(.brown)
                .padding(.horizontal, 10).padding(.vertical, 7).background(Color.kindCream.opacity(0.8), in: Capsule())
            Divider()
            HStack(spacing: 28) {
                Button { withAnimation(.spring(response: 0.25)) { store.toggleThanks(post) } } label: {
                    Label("\(post.thanks) thanks", systemImage: post.isThanked ? "heart.fill" : "heart")
                }
                .foregroundStyle(post.isThanked ? Color.kindCoral : Color.kindMuted)
                .accessibilityLabel(post.isThanked ? "Remove thanks" : "Give thanks")
                .accessibilityValue("\(post.thanks) thanks")
                Button { showingComments = true } label: { Label("\(post.commentCount)", systemImage: "bubble.left") }
                Spacer()
                ShareLink(item: post.message) { Image(systemName: "square.and.arrow.up") }
            }.font(.caption).foregroundStyle(Color.kindMuted)
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .background(post.featured ? Color.white.opacity(0.6) : Color.clear)
        .overlay(alignment: .bottom) { Divider() }
        .sheet(isPresented: $showingComments) { CommentsView(postID: post.id) }
        .confirmationDialog("Delete this story?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete story", role: .destructive) { store.deletePost(post.id, authoredBy: post.author.handle) }
        } message: {
            Text("This removes the story and its replies from this device.")
        }
    }
}

struct Avatar: View {
    let person: Person
    var size: CGFloat = 43
    var body: some View {
        Group {
            if let data = person.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(person.initials).font(.system(size: size * 0.28, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(person.color.gradient)
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3)).shadow(color: .black.opacity(0.1), radius: 2)
        .accessibilityLabel("\(person.name)'s profile photo")
    }
}

struct HeartLogo: View {
    let size: CGFloat
    var body: some View {
        Image(systemName: "heart.fill").font(.system(size: size * 0.52, weight: .bold)).foregroundStyle(.white)
            .frame(width: size, height: size).background(Color.kindCoral.gradient, in: RoundedRectangle(cornerRadius: size * 0.3))
            .rotationEffect(.degrees(-5)).shadow(color: Color.kindCoral.opacity(0.2), radius: 7, y: 3)
    }
}

struct GardenArtwork: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [.kindTeal.opacity(0.4), .kindCream]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.fill(Path(ellipseIn: CGRect(x: size.width - 70, y: 20, width: 32, height: 32)), with: .color(.orange.opacity(0.7)))
            var hill = Path(); hill.move(to: CGPoint(x: 0, y: size.height)); hill.addCurve(to: CGPoint(x: size.width, y: size.height), control1: CGPoint(x: size.width * 0.25, y: size.height * 0.25), control2: CGPoint(x: size.width * 0.65, y: size.height * 0.55)); hill.closeSubpath()
            context.fill(hill, with: .color(.kindGreen.opacity(0.85)))
            for point in [CGPoint(x: 90, y: 105), CGPoint(x: 150, y: 125), CGPoint(x: 230, y: 103)] {
                context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 13, height: 13)), with: .color(.kindCoral))
            }
        }.frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

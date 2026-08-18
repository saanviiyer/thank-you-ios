import SwiftUI

@main
struct ThankYouApp: App {
    @StateObject private var store = KindnessStore()
    @StateObject private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.currentUser != nil { ContentView() }
                else { AuthRootView() }
            }
                .environmentObject(store)
                .environmentObject(auth)
                .tint(.kindCoral)
                .onAppear { activateCurrentAccount() }
                .onChange(of: auth.currentUser?.id) { _, _ in activateCurrentAccount() }
        }
    }

    private func activateCurrentAccount() {
        guard let user = auth.currentUser else { return }
        store.activate(userID: user.id, handle: user.person.handle)
    }
}

import SwiftUI

enum AuthMode { case welcome, signUp, signIn }

struct AuthRootView: View {
    @State private var mode: AuthMode = .welcome
    var body: some View {
        ZStack {
            Color.kindBackground.ignoresSafeArea()
            switch mode {
            case .welcome: WelcomeView(mode: $mode)
            case .signUp: AccountForm(mode: .signUp, route: $mode)
            case .signIn: AccountForm(mode: .signIn, route: $mode)
            }
        }.animation(.easeInOut(duration: 0.25), value: mode)
    }
}

struct WelcomeView: View {
    @Binding var mode: AuthMode
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color.kindCream).frame(width: 180, height: 180)
                Circle().stroke(Color.kindCoral.opacity(0.18), lineWidth: 2).frame(width: 230, height: 230)
                HeartLogo(size: 105)
            }.padding(.bottom, 42)
            Text("thank you").font(.system(size: 46, weight: .bold, design: .serif)).foregroundStyle(Color.kindInk)
            Text("Kindness, shared.").font(.title3).foregroundStyle(Color.kindMuted).padding(.top, 7)
            Text("A place to notice the good, celebrate kind people,\nand make someone's day.").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary).lineSpacing(3).padding(.top, 20)
            Spacer()
            VStack(spacing: 12) {
                Button { mode = .signUp } label: { Text("Create your account").primaryAuthButton() }
                Button { mode = .signIn } label: { Text("I already have an account").fontWeight(.semibold).frame(maxWidth: .infinity).padding(16).background(Color.kindCream, in: RoundedRectangle(cornerRadius: 13)) }
            }
        }.padding(.horizontal, 25).padding(.bottom, 20)
    }
}

struct AccountForm: View {
    @EnvironmentObject private var auth: AuthStore
    let mode: AuthMode
    @Binding var route: AuthMode
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var bio = ""
    @FocusState private var focused: Field?
    enum Field { case name, username, email, password, bio }
    var isSignUp: Bool { mode == .signUp }
    var canSubmit: Bool { !email.isEmpty && !password.isEmpty && (!isSignUp || (!name.isEmpty && !username.isEmpty)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button { route = .welcome } label: { Image(systemName: "chevron.left").font(.headline).frame(width: 42, height: 42).background(Color.kindCream, in: Circle()) }
                VStack(alignment: .leading, spacing: 8) {
                    Label(isSignUp ? "JOIN THE GOOD" : "WELCOME BACK", systemImage: "sparkles").font(.caption2.bold()).tracking(1.4).foregroundStyle(Color.kindCoral)
                    Text(isSignUp ? "Make kindness social." : "Good to see you.").font(.system(size: 34, weight: .bold, design: .serif))
                    Text(isSignUp ? "Create an account to share, thank, and connect." : "Sign in to see what's good today.").foregroundStyle(.secondary)
                }
                VStack(spacing: 14) {
                    if isSignUp {
                        AuthField(title: "Your name", icon: "person", text: $name).focused($focused, equals: .name).textContentType(.name)
                        AuthField(title: "Username", icon: "at", text: $username).focused($focused, equals: .username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        AuthField(title: "Short bio (optional)", icon: "quote.bubble", text: $bio).focused($focused, equals: .bio)
                    }
                    AuthField(title: "Email", icon: "envelope", text: $email).focused($focused, equals: .email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.emailAddress)
                    HStack(spacing: 12) { Image(systemName: "lock").foregroundStyle(Color.kindMuted).frame(width: 20); SecureField("Password", text: $password).focused($focused, equals: .password).textContentType(isSignUp ? .newPassword : .password) }.authFieldStyle()
                    if isSignUp { Text("Use 8 or more characters with a letter and a number.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
                }
                if let error = auth.errorMessage { Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)).accessibilityLabel("Error: \(error)") }
                Button(action: submit) { Text(isSignUp ? "Create account" : "Sign in").primaryAuthButton() }.disabled(!canSubmit).opacity(canSubmit ? 1 : 0.45)
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already a member?" : "New around here?").foregroundStyle(.secondary)
                    Button(isSignUp ? "Sign in" : "Create account") { route = isSignUp ? .signIn : .signUp }.fontWeight(.bold).foregroundStyle(Color.kindCoral)
                }.font(.subheadline).frame(maxWidth: .infinity)
            }.padding(25)
        }.scrollDismissesKeyboard(.interactively)
            .onAppear { auth.errorMessage = nil }
    }
    private func submit() {
        focused = nil
        if isSignUp { _ = auth.signUp(name: name, username: username, email: email, password: password, bio: bio) }
        else { _ = auth.signIn(email: email, password: password) }
    }
}

struct AuthField: View {
    let title: String; let icon: String; @Binding var text: String
    var body: some View { HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(Color.kindMuted).frame(width: 20); TextField(title, text: $text) }.authFieldStyle() }
}

extension View {
    fileprivate func authFieldStyle() -> some View { self.padding(.horizontal, 16).frame(height: 56).background(.white, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.black.opacity(0.07))) }
    fileprivate func primaryAuthButton() -> some View { self.fontWeight(.bold).foregroundStyle(.white).frame(maxWidth: .infinity).padding(17).background(Color.kindCoral, in: RoundedRectangle(cornerRadius: 13)).shadow(color: Color.kindCoral.opacity(0.22), radius: 12, y: 6) }
}

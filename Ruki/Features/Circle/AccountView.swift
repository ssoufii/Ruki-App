import SwiftUI

/// Log in or create an account, so friends can find each other by username.
/// Optional: nothing in Ruki needs it, and the copy says so.
struct AccountView: View {
    let session: SocialSession
    /// Set on the launch prompt only, where signing in is optional (R7).
    var onSkip: (() -> Void)?

    private enum Mode: String, CaseIterable, Identifiable {
        case logIn, create
        var id: String { rawValue }
        var title: LocalizedStringKey { self == .logIn ? "Log in" : "Create account" }
    }

    private enum Field { case username, password }

    @State private var mode: Mode = .create
    @State private var username = ""
    @State private var password = ""
    @State private var showingServer = false
    @FocusState private var focus: Field?

    private var normalizedUsername: String { SocialSession.normalizedUsername(username) }

    /// What's still missing on Create, in words — so a greyed-out button is never a mystery.
    private var problem: String? {
        guard mode == .create else { return nil }
        if !normalizedUsername.isEmpty,
           normalizedUsername.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) == nil {
            return String(localized: "Your name can use 3–20 letters and numbers. Please leave out symbols.")
        }
        if password.count < 8 {
            return String(localized: "Your password needs at least 8 characters (\(password.count) so far).")
        }
        return nil
    }

    /// Shown once the name is fine but differs from what was typed, e.g. "Sumeya Farah".
    private var preview: String? {
        guard mode == .create, problem == nil || password.count < 8, !normalizedUsername.isEmpty,
              normalizedUsername != username.trimmingCharacters(in: .whitespaces) else { return nil }
        return String(localized: "Friends will find you as \(normalizedUsername)")
    }

    private var canSubmit: Bool {
        guard !normalizedUsername.isEmpty, !session.isBusy else { return false }
        return mode == .logIn ? !password.isEmpty : problem == nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(RukiPalette.accent)
                        .accessibilityHidden(true)
                    Text("Ruki")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(RukiPalette.primaryText)
                    Text("Stay consistent with your prayers, together. Friends only ever see that you checked in — never a missed prayer.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(RukiPalette.secondaryText)
                }
                .padding(.top, 8)

                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 0) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                        .padding()
                    Divider()
                    SecureField(mode == .create ? "Password (8+ characters)" : "Password", text: $password)
                        .textContentType(mode == .create ? .newPassword : .password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { if canSubmit { submit() } }
                        .padding()
                }
                .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 16))

                if let note = problem ?? preview {
                    Text(note)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(RukiPalette.secondaryText)
                }

                if let message = session.message {
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(RukiPalette.secondaryText)
                }

                Button(action: submit) {
                    Group {
                        if session.isBusy { ProgressView() } else { Text(mode == .create ? "Create account" : "Log in") }
                    }
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .background(RukiPalette.accent.opacity(canSubmit ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 12))
                .disabled(!canSubmit)

                DisclosureGroup("Server", isExpanded: $showingServer) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Server address", text: serverBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .padding()
                            .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                        Text("Simulator: http://localhost:8080. On a phone, use your Mac's address, e.g. http://192.168.1.10:8080.")
                            .font(.footnote)
                            .foregroundStyle(RukiPalette.secondaryText)
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)

                if let onSkip {
                    Button("Continue without an account", action: onSkip)
                        .font(.subheadline)
                        .foregroundStyle(RukiPalette.secondaryText)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(RukiPalette.background)
        .onChange(of: mode) { _, _ in password = "" }
    }

    private var serverBinding: Binding<String> {
        Binding(get: { session.serverURLString }, set: { session.serverURLString = $0 })
    }

    private func submit() {
        focus = nil
        let name = username, secret = password
        Task {
            if mode == .create {
                await session.register(username: name, password: secret)
            } else {
                await session.logIn(username: name, password: secret)
            }
        }
    }
}

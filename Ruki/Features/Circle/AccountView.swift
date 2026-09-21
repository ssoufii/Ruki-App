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

    private var canSubmit: Bool {
        let name = username.trimmingCharacters(in: .whitespaces)
        return !name.isEmpty && (mode == .logIn ? !password.isEmpty : password.count >= 8) && !session.isBusy
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(RukiPalette.accent)
                        .accessibilityHidden(true)
                    Text("Your circle")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(RukiPalette.primaryText)
                    Text("Add up to five people you trust. They only ever see that you checked in — never a missed prayer.")
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

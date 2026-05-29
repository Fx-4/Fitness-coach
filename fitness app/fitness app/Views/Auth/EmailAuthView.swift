import SwiftUI

struct EmailAuthView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var showReset = false
    @State private var resetEmail = ""
    @State private var resetSent  = false
    private enum Mode { case signIn, signUp }

    // When used for guest upgrade (linking), pass isLinking = true
    var isLinking: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {

                    if !isLinking {
                        Picker("", selection: $mode) {
                            Text("Sign In").tag(Mode.signIn)
                            Text("Create Account").tag(Mode.signUp)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: mode) { _ in authVM.error = nil }
                    }

                    VStack(spacing: DesignTokens.Spacing.sm) {
                        if mode == .signUp || isLinking {
                            InputField(placeholder: "Your name (optional)", text: $name,
                                       type: .name, icon: "person")
                        }

                        InputField(placeholder: "Email", text: $email,
                                   type: .email, icon: "envelope")

                        InputField(placeholder: "Password", text: $password,
                                   type: .password, icon: "lock", isSecure: true)
                    }

                    // Main action
                    Button {
                        Task {
                            if isLinking {
                                await authVM.linkWithEmail(email: email, password: password)
                                if authVM.error == nil { dismiss() }
                            } else if mode == .signUp {
                                await authVM.signUp(email: email, password: password, displayName: name)
                                if authVM.isAuthenticated { dismiss() }
                            } else {
                                await authVM.signIn(email: email, password: password)
                                if authVM.isAuthenticated { dismiss() }
                            }
                        }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(buttonLabel)
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(canSubmit ? Color.orange : Color.orange.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    }
                    .disabled(!canSubmit || authVM.isLoading)

                    // Forgot password (sign-in only)
                    if mode == .signIn && !isLinking {
                        Button("Forgot password?") { showReset = true }
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .navigationTitle(isLinking ? "Link Email Account" : (mode == .signIn ? "Sign In" : "Create Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .alert("Sign-In Error", isPresented: Binding(
            get: { authVM.error != nil },
            set: { if !$0 { authVM.error = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(authVM.error ?? "")
        }
        .alert("Reset Password", isPresented: $showReset) {
            TextField("Email", text: $resetEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            Button("Send") {
                Task {
                    await authVM.sendPasswordReset(email: resetEmail)
                    resetSent = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your email address and we'll send a reset link.")
        }
        .alert("Email Sent", isPresented: $resetSent) {
            Button("OK") {}
        } message: {
            Text("Check your inbox for the password reset link.")
        }
    }

    private var buttonLabel: String {
        if isLinking    { return "Link Account" }
        if mode == .signUp { return "Create Account" }
        return "Sign In"
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6
    }
}

// MARK: - Reusable input field

private struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var type: FieldType = .text
    var icon: String
    var isSecure: Bool = false

    enum FieldType { case name, email, password, text }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(.password)
            } else {
                TextField(placeholder, text: $text)
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .autocapitalization(autocap)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }

    private var contentType: UITextContentType? {
        switch type {
        case .name:     return .name
        case .email:    return .emailAddress
        case .password: return .password
        default:        return nil
        }
    }
    private var keyboardType: UIKeyboardType {
        type == .email ? .emailAddress : .default
    }
    private var autocap: UITextAutocapitalizationType {
        type == .email ? .none : (type == .name ? .words : .sentences)
    }
}

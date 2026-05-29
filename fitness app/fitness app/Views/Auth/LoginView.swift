import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showEmailSheet = false
    @State private var showErrorAlert  = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.orange.opacity(0.15), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: Logo
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.orange)
                        .shadow(color: .orange.opacity(0.3), radius: 16, y: 8)

                    Text("FitCoach")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("Your AI-powered fitness companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // MARK: Auth buttons
                VStack(spacing: DesignTokens.Spacing.sm) {

                    // Email
                    Button { showEmailSheet = true } label: {
                        Label("Continue with Email", systemImage: "envelope.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    }

                    // Google
                    Button {
                        Task { await authVM.signInWithGoogle() }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "globe")
                                .font(.headline)
                            Text("Continue with Google")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(.regularMaterial)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                    }

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(Color.secondary.opacity(0.2))
                        Text("or").font(.caption).foregroundStyle(.secondary)
                        Rectangle().frame(height: 1).foregroundStyle(Color.secondary.opacity(0.2))
                    }

                    // Guest
                    Button {
                        Task { await authVM.continueAsGuest() }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView().tint(.secondary)
                            } else {
                                Text("Continue as Guest")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.sm)
                    }
                    .disabled(authVM.isLoading)

                    Text("Guest data is saved and can be linked to a full account anytime")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailAuthView()
                .environmentObject(authVM)
        }
        .onChange(of: authVM.error) { newValue in
            if newValue != nil { showErrorAlert = true }
        }
        .alert("Sign-In Error", isPresented: $showErrorAlert) {
            Button("OK") { authVM.error = nil }
        } message: {
            Text(authVM.error ?? "")
        }
    }
}

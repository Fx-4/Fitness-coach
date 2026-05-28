import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isEditing = false
    @State private var showUpgradeSheet = false
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                statsSection
                goalsSection
                fitnessSection
                accountSection
                appSection
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing { viewModel.save(to: store) }
                        isEditing.toggle()
                    }
                    .bold()
                }
            }
            .onAppear { viewModel.load(from: store.profile) }
        }
    }

    // MARK: - Sections

    private var statsSection: some View {
        Section("About You") {
            LabeledContent("Name") {
                if isEditing {
                    TextField("Your name", text: $viewModel.name)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(viewModel.name.isEmpty ? "Not set" : viewModel.name)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Age") {
                if isEditing {
                    Stepper("\(viewModel.age) years", value: $viewModel.age, in: 13...99)
                } else {
                    Text("\(viewModel.age) years").foregroundStyle(.secondary)
                }
            }

            LabeledContent("Weight") {
                if isEditing {
                    HStack {
                        Slider(value: $viewModel.weightKg, in: 30...200, step: 0.5)
                        Text(viewModel.weightKg.formatted(.number.precision(.fractionLength(1))) + " kg")
                            .font(.subheadline)
                            .frame(width: 64, alignment: .trailing)
                    }
                } else {
                    Text(viewModel.weightKg.formatted(.number.precision(.fractionLength(1))) + " kg")
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Height") {
                if isEditing {
                    HStack {
                        Slider(value: $viewModel.heightCm, in: 120...220, step: 0.5)
                        Text(viewModel.heightCm.formatted(.number.precision(.fractionLength(0))) + " cm")
                            .font(.subheadline)
                            .frame(width: 64, alignment: .trailing)
                    }
                } else {
                    Text(viewModel.heightCm.formatted(.number.precision(.fractionLength(0))) + " cm")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var goalsSection: some View {
        Section("Goals") {
            LabeledContent("Daily Active Calorie Goal") {
                if isEditing {
                    Stepper(
                        "\(viewModel.dailyCalorieGoal) kcal",
                        value: $viewModel.dailyCalorieGoal,
                        in: 100...2000,
                        step: 50
                    )
                } else {
                    Text("\(viewModel.dailyCalorieGoal) kcal").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var fitnessSection: some View {
        Section("Fitness") {
            if isEditing {
                Picker("Fitness Level", selection: $viewModel.fitnessLevel) {
                    ForEach(FitnessLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            } else {
                LabeledContent("Fitness Level", value: viewModel.fitnessLevel.rawValue)
            }
            LabeledContent("Est. BMI", value: viewModel.bmiFormatted)
            LabeledContent("Est. TDEE", value: viewModel.tdeeFormatted + " kcal/day")
        }
    }

    // MARK: - Account section

    private var accountSection: some View {
        Section("Account") {
            // Identity row
            if authVM.isGuest {
                HStack {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Guest Account")
                            .font(.subheadline.bold())
                        Text("Data saved locally & synced. Upgrade to keep it forever.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                // Upgrade to Email
                Button {
                    showUpgradeSheet = true
                } label: {
                    Label("Link Email & Password", systemImage: "envelope.badge.shield.half.filled.fill")
                        .foregroundStyle(.orange)
                }

                // Upgrade to Google
                Button {
                    Task { await authVM.linkWithGoogle() }
                } label: {
                    Label("Link Google Account", systemImage: "globe.badge.chevron.backward")
                        .foregroundStyle(.blue)
                }

                if let err = authVM.error {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

            } else {
                // Signed-in user
                HStack {
                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authVM.displayName ?? authVM.userEmail ?? "Signed in")
                            .font(.subheadline.bold())
                        if let email = authVM.userEmail {
                            Text(email).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Sign out (always shown)
            Button(role: .destructive) {
                showSignOutConfirm = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            EmailAuthView(isLinking: true)
                .environmentObject(authVM)
        }
        .confirmationDialog("Sign out of FitCoach?", isPresented: $showSignOutConfirm,
                            titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authVM.signOut() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var appSection: some View {
        Section("App") {
            LabeledContent("Version", value: Bundle.main.appVersion)
        }
    }
}

private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

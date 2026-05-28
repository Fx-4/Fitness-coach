import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppDataStore
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                statsSection
                goalsSection
                fitnessSection
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

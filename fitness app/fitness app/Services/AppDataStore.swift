import Foundation
import Combine

/// Central in-memory store persisted to UserDefaults + synced to Firestore.
/// Works on iOS 16+.
final class AppDataStore: ObservableObject {
    static let shared = AppDataStore()

    // MARK: - Published state

    @Published var profile: UserProfile {
        didSet {
            save(profile, key: Keys.profile)
            Task { try? await FirestoreService.shared.saveProfile(profile) }
        }
    }

    @Published var workoutSessions: [WorkoutSession] {
        didSet { save(workoutSessions, key: Keys.sessions) }
    }

    @Published var nutritionEntries: [NutritionEntry] {
        didSet { save(nutritionEntries, key: Keys.nutrition) }
    }

    @Published var approvedCoachSchedule: CoachScheduleDraft? {
        didSet { saveOptional(approvedCoachSchedule, key: Keys.coachSchedule) }
    }

    @Published var savedCoachSchedules: [CoachScheduleDraft] {
        didSet { save(savedCoachSchedules, key: Keys.savedCoachSchedules) }
    }

    // MARK: - Keys

    private enum Keys {
        static let profile              = "fitcoach.profile"
        static let sessions             = "fitcoach.sessions"
        static let nutrition            = "fitcoach.nutrition"
        static let coachSchedule        = "fitcoach.coachSchedule"
        static let savedCoachSchedules  = "fitcoach.savedCoachSchedules"
    }

    // MARK: - Init

    private init() {
        self.profile              = Self.load(UserProfile.self,        key: Keys.profile)              ?? UserProfile()
        self.workoutSessions      = Self.load([WorkoutSession].self,   key: Keys.sessions)             ?? []
        self.nutritionEntries     = Self.load([NutritionEntry].self,   key: Keys.nutrition)            ?? []
        self.approvedCoachSchedule = Self.load(CoachScheduleDraft.self, key: Keys.coachSchedule)
        self.savedCoachSchedules  = Self.load([CoachScheduleDraft].self, key: Keys.savedCoachSchedules) ?? []

        // Pull remote data on first launch (fill in any sessions from other devices)
        Task { await syncFromFirestore() }
    }

    // MARK: - Session mutations

    func addSession(_ session: WorkoutSession) {
        workoutSessions.append(session)
        Task { try? await FirestoreService.shared.saveSession(session) }
    }

    // MARK: - Nutrition

    func addNutrition(_ entry: NutritionEntry) {
        nutritionEntries.append(entry)
    }

    // MARK: - Coach schedules

    func approveCoachSchedule(_ draft: CoachScheduleDraft) {
        upsertCoachSchedule(draft)
    }

    func upsertCoachSchedule(_ draft: CoachScheduleDraft) {
        if let idx = savedCoachSchedules.firstIndex(where: { $0.id == draft.id }) {
            savedCoachSchedules[idx] = draft
        } else {
            savedCoachSchedules.insert(draft, at: 0)
        }

        // Mirror goal settings into profile
        var updatedProfile = profile
        updatedProfile.dailyCalorieGoal = draft.goal.dailyCalorieGoal
        updatedProfile.fitnessLevel     = draft.goal.fitnessLevel
        profile = updatedProfile

        approvedCoachSchedule = draft

        Task { try? await FirestoreService.shared.saveSchedule(draft) }
    }

    func deleteCoachSchedule(_ draft: CoachScheduleDraft) {
        savedCoachSchedules.removeAll { $0.id == draft.id }
        if approvedCoachSchedule?.id == draft.id {
            approvedCoachSchedule = savedCoachSchedules.first
        }
        Task { try? await FirestoreService.shared.deleteSchedule(draft) }
    }

    // MARK: - Derived queries

    /// Sessions completed in the last 7 days
    var recentSessions: [WorkoutSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workoutSessions.filter { $0.startedAt >= cutoff && $0.isCompleted }
    }

    /// Total calories burned today from completed sessions
    var todaySessionCalories: Double {
        let start = Calendar.current.startOfDay(for: Date())
        return workoutSessions
            .filter { $0.isCompleted && $0.startedAt >= start }
            .reduce(0) { $0 + $1.activeCaloriesBurned }
    }

    // MARK: - Firestore sync (on launch)

    @MainActor
    private func syncFromFirestore() async {
        // Pull remote sessions and merge (remote wins for unknown IDs)
        if let remoteSessions = try? await FirestoreService.shared.fetchSessions() {
            let localIDs = Set(workoutSessions.map { $0.id })
            let newRemote = remoteSessions.filter { !localIDs.contains($0.id) }
            if !newRemote.isEmpty {
                workoutSessions.append(contentsOf: newRemote)
                workoutSessions.sort { $0.startedAt > $1.startedAt }
            }
        }

        // Pull remote schedules and merge
        if let remoteSchedules = try? await FirestoreService.shared.fetchSchedules() {
            let localIDs = Set(savedCoachSchedules.map { $0.id })
            let newRemote = remoteSchedules.filter { !localIDs.contains($0.id) }
            if !newRemote.isEmpty {
                savedCoachSchedules.append(contentsOf: newRemote)
            }
        }
    }

    // MARK: - UserDefaults persistence helpers

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func saveOptional<T: Encodable>(_ value: T?, key: String) {
        guard let value else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        save(value, key: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - FirestoreService
// ─────────────────────────────────────────────────────────
// Syncs app data to Firestore (write-through).
// Collection layout under users/{deviceID}/:
//   • profile       → map (UserProfile fields)
//   • sessions/     → sub-collection of WorkoutSession
//   • schedules/    → sub-collection of CoachScheduleDraft
// ─────────────────────────────────────────────────────────

final class FirestoreService {
    static let shared = FirestoreService()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - User identity (Firebase Auth UID — anonymous or full account)

    var userID: String {
        // Prefer Firebase Auth UID (works for anon, email, google — preserved on linking)
        if let uid = Auth.auth().currentUser?.uid { return uid }
        // Fallback: local UUID for offline/pre-auth state
        let key = "fitcoach.userID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    private var userRef: DocumentReference {
        db.collection("users").document(userID)
    }

    // MARK: - Sessions

    func saveSession(_ session: WorkoutSession) async throws {
        let dict = try encode(session)
        try await userRef.collection("sessions")
            .document(session.id.uuidString)
            .setData(dict)
    }

    func deleteSession(_ session: WorkoutSession) async throws {
        try await userRef.collection("sessions")
            .document(session.id.uuidString)
            .delete()
    }

    func fetchSessions() async throws -> [WorkoutSession] {
        let snap = try await userRef.collection("sessions")
            .order(by: "startedAt", descending: true)
            .limit(to: 200)
            .getDocuments()
        return snap.documents.compactMap { try? decode(WorkoutSession.self, from: $0.data()) }
    }

    // MARK: - Profile

    func saveProfile(_ profile: UserProfile) async throws {
        let dict = try encode(profile)
        try await userRef.setData(["profile": dict], merge: true)
    }

    func fetchProfile() async throws -> UserProfile? {
        let doc = try await userRef.getDocument()
        guard let map = doc.data()?["profile"] as? [String: Any] else { return nil }
        return try? decode(UserProfile.self, from: map)
    }

    // MARK: - Schedules

    func saveSchedule(_ draft: CoachScheduleDraft) async throws {
        let dict = try encode(draft)
        try await userRef.collection("schedules")
            .document(draft.id.uuidString)
            .setData(dict)
    }

    func deleteSchedule(_ draft: CoachScheduleDraft) async throws {
        try await userRef.collection("schedules")
            .document(draft.id.uuidString)
            .delete()
    }

    func fetchSchedules() async throws -> [CoachScheduleDraft] {
        let snap = try await userRef.collection("schedules").getDocuments()
        return snap.documents.compactMap { try? decode(CoachScheduleDraft.self, from: $0.data()) }
    }

    // MARK: - Codable ↔ Firestore dict helpers
    // Dates are stored as ISO‑8601 strings — safe roundtrip regardless of Firestore Timestamp handling.

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FirestoreError.encodingFailed
        }
        return dict
    }

    private func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(type, from: data)
    }

    enum FirestoreError: Error {
        case encodingFailed
    }
}

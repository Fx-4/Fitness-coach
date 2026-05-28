import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: FirebaseAuth.User? = nil
    @Published var isLoading = false
    @Published var error: String? = nil

    var isAuthenticated: Bool { currentUser != nil }
    var isGuest: Bool       { currentUser?.isAnonymous == true }
    var userEmail: String?  { currentUser?.email }
    var displayName: String? { currentUser?.displayName }

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        // Sync with whatever Firebase already has (persists across launches)
        currentUser = Auth.auth().currentUser
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
            }
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    // MARK: - Anonymous

    func continueAsGuest() async {
        await run { try await Auth.auth().signInAnonymously() }
    }

    // MARK: - Email / Password

    func signIn(email: String, password: String) async {
        await run { try await Auth.auth().signIn(withEmail: email, password: password) }
    }

    func signUp(email: String, password: String, displayName: String) async {
        await run {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let req = result.user.createProfileChangeRequest()
            req.displayName = displayName.isEmpty ? nil : displayName
            try await req.commitChanges()
        }
    }

    // MARK: - Link guest → Email (keeps all existing data!)

    func linkWithEmail(email: String, password: String) async {
        await run {
            guard let user = Auth.auth().currentUser, user.isAnonymous else { return }
            let cred = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.link(with: cred)
        }
    }

    // MARK: - Google Sign-In  (wired but needs CLIENT_ID in GoogleService-Info.plist)
    //   1. Enable Google in Firebase Console → Authentication → Sign-in methods
    //   2. Re-download GoogleService-Info.plist (CLIENT_ID field appears)
    //   3. Set REVERSED_CLIENT_ID as a URL scheme in Info.plist
    //   4. Add GoogleSignIn-iOS via SPM and uncomment the implementation below

    func signInWithGoogle() async {
        error = "Google Sign-In: enable it in Firebase Console and re-download GoogleService-Info.plist first."
    }

    func linkWithGoogle() async {
        error = "Google linking: enable Google Sign-In in Firebase Console first."
    }

    // MARK: - Password reset

    func sendPasswordReset(email: String) async {
        await run { try await Auth.auth().sendPasswordReset(withEmail: email) }
    }

    // MARK: - Sign out

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Delete guest account

    func deleteAccount() async {
        await run { try await Auth.auth().currentUser?.delete() }
    }

    // MARK: - Private

    private func run(_ block: @escaping () async throws -> Void) async {
        isLoading = true
        error = nil
        do {
            try await block()
        } catch {
            let msg = friendlyMessage(for: error)
            print("🔴 [AuthViewModel] error code=\((error as NSError).code) domain=\((error as NSError).domain) → \(msg)")
            self.error = msg
        }
        isLoading = false
    }

    private func friendlyMessage(for error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:    return "Email already in use. Try signing in instead."
        case AuthErrorCode.invalidEmail.rawValue:         return "Invalid email address."
        case AuthErrorCode.weakPassword.rawValue:         return "Password must be at least 6 characters."
        case AuthErrorCode.wrongPassword.rawValue:        return "Wrong password."
        case AuthErrorCode.userNotFound.rawValue:         return "No account found with that email."
        case AuthErrorCode.networkError.rawValue:         return "Network error. Check your connection."
        case AuthErrorCode.credentialAlreadyInUse.rawValue: return "This account is already linked to another user."
        case AuthErrorCode.providerAlreadyLinked.rawValue:  return "Account already linked."
        case AuthErrorCode.operationNotAllowed.rawValue:    return "This sign-in method is not enabled. Enable it in Firebase Console → Authentication → Sign-in methods."
        case AuthErrorCode.appNotAuthorized.rawValue:       return "App not authorized. Check that the bundle ID matches Firebase Console."
        case 17020:                                         return "Network timeout. Check your internet connection."
        default:                                            return error.localizedDescription
        }
    }
}

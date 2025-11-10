import Foundation
import Supabase
import Combine
import AuthenticationServices
import Auth

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    @Published var isSignedIn = false
    @Published var userId: String?
    @Published var isInitializing = true  // ✅ NEW: Loading state
    
    private var authStateTask: Task<Void, Never>?
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: "https://yykxwlioounydxjikbjs.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5a3h3bGlvb3VueWR4amlrYmpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NzU4NjYsImV4cCI6MjA3NTM1MTg2Nn0.u2U6xApU-ViMe1FO5TtRa31-y76nEgohsF1jJ63rk0Q"
        )
        
        // ✅ Check session on launch
        Task {
            await checkExistingSession()
            setupAuthStateListener()
            self.isInitializing = false
        }
    }
    
    // MARK: - Session Restoration
    
    /// Checks if user has valid session AND exists in database
    private func checkExistingSession() async {
        do {
            // Step 1: Check if auth session exists
            let session = try await client.auth.session
            let sessionUserId = session.user.id.uuidString
            
            print("🔍 Found auth session for user: \(sessionUserId)")
            
            // Step 2: Verify user EXISTS in database
            do {
                let _: BrainTwinUser = try await client
                    .from("users")
                    .select()
                    .eq("id", value: sessionUserId)
                    .single()
                    .execute()
                    .value
                
                // ✅ Session valid AND user exists in database
                self.isSignedIn = true
                self.userId = sessionUserId
                print("✅ Session restored! User exists in database. User ID: \(sessionUserId)")
                
            } catch {
                // ❌ Session exists but user NOT in database - SIGN OUT
                print("⚠️ Session exists but user NOT in database. Signing out...")
                try? await client.auth.signOut()
                self.isSignedIn = false
                self.userId = nil
                print("👋 Signed out due to missing database user")
            }
            
        } catch {
            // No active session found
            self.isSignedIn = false
            self.userId = nil
            print("ℹ️ No existing session - showing sign in")
        }
    }
    
    // MARK: - Auth State Listener
    
    /// Listens for auth state changes (sign out, token refresh, etc.)
    private func setupAuthStateListener() {
        authStateTask = Task {
            for await state in await client.auth.authStateChanges {
                await handleAuthStateChange(state.event, session: state.session)
            }
        }
    }
    
    private func handleAuthStateChange(_ event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn, .tokenRefreshed:
            if let session = session {
                self.isSignedIn = true
                self.userId = session.user.id.uuidString
                print("✅ Auth state: \(event) - User ID: \(session.user.id.uuidString)")
            }
            
        case .signedOut:
            self.isSignedIn = false
            self.userId = nil
            print("👋 Auth state: User signed out")
            
        default:
            break
        }
    }
    
    // MARK: - Anonymous sign in

    func signInAnonymously() async throws {
        let session = try await client.auth.signInAnonymously()
        self.isSignedIn = true
        self.userId = session.user.id.uuidString
        print("✅ Signed in! User ID: \(session.user.id.uuidString)")
        
        // Create user in database
        try await createUserIfNeeded(userId: session.user.id.uuidString)
    }

    private func createUserIfNeeded(userId: String) async throws {
        // Check if user exists
        do {
            let _: BrainTwinUser = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            print("✅ User already exists in database")
        } catch {
            // User doesn't exist, create them
            print("📝 Creating new user in database...")
            
            struct NewUser: Encodable {
                let id: String
                let email: String
                let main_struggle: String
                let rewire_progress: Double
                let current_streak: Int
                let skill_level: String
                let onboarding_completed: Bool
            }
            
            let newUser = NewUser(
                id: userId,
                email: "anon-\(userId.prefix(8))@braintwin.app",
                main_struggle: "procrastination",
                rewire_progress: 0,
                current_streak: 0,
                skill_level: "foggy",
                onboarding_completed: false
            )
            
            try await client
                .from("users")
                .insert(newUser)
                .execute()
            
            print("✅ User created in database!")
        }
    }

    struct BrainTwinUser: Codable {
        let id: String
        let email: String
        let main_struggle: String
        let rewire_progress: Double
        let current_streak: Int
        let skill_level: String
        let onboarding_completed: Bool?
        let goal: String?
        let biggest_struggle: String?
        let preferred_time: String?
        let name: String?
        let age: Int?
        
        enum CodingKeys: String, CodingKey {
            case id
            case email
            case main_struggle
            case rewire_progress
            case current_streak
            case skill_level
            case onboarding_completed
            case goal
            case biggest_struggle
            case preferred_time
            case name
            case age
        }
    }

    // MARK: - Email sign in / sign up

    func signInOrSignUpWithEmail(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            throw NSError(
                domain: "SupabaseManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Email and password are required"]
            )
        }
        
        do {
            print("🔐 Trying email sign in for \(trimmedEmail)")
            let session = try await client.auth.signIn(
                email: trimmedEmail,
                password: trimmedPassword
            )
            
            self.isSignedIn = true
            self.userId = session.user.id.uuidString
            print("✅ Email sign in success. User ID: \(session.user.id.uuidString)")
            
            try await createUserIfNeeded(userId: session.user.id.uuidString)
        } catch {
            print("⚠️ Email sign in failed, trying sign up: \(error)")
            
            let signUpResult = try await client.auth.signUp(
                email: trimmedEmail,
                password: trimmedPassword
            )
            
            let user = signUpResult.user
            
            self.isSignedIn = true
            self.userId = user.id.uuidString
            print("🆕 Email sign up success. User ID: \(user.id.uuidString)")
            
            try await createUserIfNeeded(userId: user.id.uuidString)
        }
    }

    // MARK: - Onboarding Methods

    func hasCompletedOnboarding() async -> Bool {
        guard let userId = userId else {
            print("⚠️ No userId - returning false for onboarding")
            return false
        }
        
        do {
            let user: BrainTwinUser = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            let completed = user.onboarding_completed ?? false
            print("🔍 Onboarding check for \(userId): \(completed)")
            return completed
            
        } catch {
            print("❌ Error checking onboarding: \(error)")
            return false
        }
    }

    func saveOnboardingData(name: String, age: Int, goal: String, struggle: String, preferredTime: String) async throws {
        guard let userId = userId else {
            throw NSError(
                domain: "SupabaseManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user ID found"]
            )
        }
        
        struct OnboardingUpdate: Encodable {
            let name: String
            let age: Int
            let goal: String
            let biggest_struggle: String
            let preferred_time: String
            let onboarding_completed: Bool
        }
        
        let update = OnboardingUpdate(
            name: name,
            age: age,
            goal: goal,
            biggest_struggle: struggle,
            preferred_time: preferredTime,
            onboarding_completed: true
        )
        
        try await client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()
        
        print("✅ Onboarding COMPLETED and saved for user \(userId)")
    }

    // MARK: - Sign in with Apple

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        nonce: String? = nil
    ) async throws {
        guard
            let identityToken = credential.identityToken,
            let tokenString = String(data: identityToken, encoding: .utf8)
        else {
            throw NSError(
                domain: "SupabaseManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to decode Apple identity token"]
            )
        }

        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: tokenString,
                nonce: nonce
            )
        )

        self.isSignedIn = true
        self.userId = session.user.id.uuidString
        print("✅ Signed in with Apple. User ID: \(session.user.id.uuidString)")

        try await createUserIfNeeded(userId: session.user.id.uuidString)
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
        self.isSignedIn = false
        self.userId = nil
        
        // ✅ Clear local storage
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        
        print("👋 Signed out successfully")
    }

    // MARK: - API Calls

    func getMeterData(userId: String) async throws -> MeterResponse {
        print("📊 Fetching meter data for user: \(userId)")
        
        let response: MeterResponse = try await client.functions.invoke(
            "calculate-meter",
            options: FunctionInvokeOptions(
                body: ["userId": userId]
            )
        )
        
        print("✅ Meter data received: \(response.progress)% progress")
        return response
    }
}

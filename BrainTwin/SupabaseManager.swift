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
    @Published var isInitializing = true
    
    private var authStateTask: Task<Void, Never>?
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: "https://yykxwlioounydxjikbjs.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5a3h3bGlvb3VueWR4amlrYmpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NzU4NjYsImV4cCI6MjA3NTM1MTg2Nn0.u2U6xApU-ViMe1FO5TtRa31-y76nEgohsF1jJ63rk0Q"
        )
        
        print("🔧 SupabaseManager initialized")
        
        Task {
            await checkExistingSession()
            setupAuthStateListener()
            self.isInitializing = false
        }
    }
    
    // MARK: - Session Restoration
    
    private func checkExistingSession() async {
        do {
            let session = try await client.auth.session
            let sessionUserId = session.user.id.uuidString
            
            print("🔍 Found auth session for user: \(sessionUserId)")
            
            do {
                let _: BrainTwinUser = try await client
                    .from("users")
                    .select()
                    .eq("id", value: sessionUserId)
                    .single()
                    .execute()
                    .value
                
                self.isSignedIn = true
                self.userId = sessionUserId
                print("✅ Session restored! User exists in database. User ID: \(sessionUserId)")
                
            } catch {
                print("⚠️ Session exists but user NOT in database. Signing out...")
                try? await client.auth.signOut()
                self.isSignedIn = false
                self.userId = nil
                print("👋 Signed out due to missing database user")
            }
            
        } catch {
            self.isSignedIn = false
            self.userId = nil
            print("ℹ️ No existing session - showing sign in")
        }
    }
    
    // MARK: - Auth State Listener
    
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

        try await createUserIfNeeded(userId: session.user.id.uuidString)
    }

    // MARK: - Create user if needed

    func createUserIfNeeded(userId: String) async throws {
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
            print("📝 User does not exist, creating...")
            
            struct NewUser: Encodable {
                let id: String
                let email: String
                let main_struggle: String
                let rewire_progress: Double
                let current_streak: Int
                let skill_level: String
                let created_at: String
            }
            
            let newUser = NewUser(
                id: userId,
                email: "\(userId)@anon.braintwin.app",
                main_struggle: "Not specified",
                rewire_progress: 0,
                current_streak: 0,
                skill_level: "foggy",
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client
                .from("users")
                .insert(newUser)
                .execute()
            
            print("✅ User created successfully")
        }
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
        self.isSignedIn = false
        self.userId = nil
        
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
    
    // MARK: - Receipt-Based Authentication (UNIFIED)
    
    /// Unified function: Identifies or creates user from Apple receipt
    /// Works for BOTH first-time users AND returning users
    func identifyUserFromReceipt(originalTransactionId: String, onboardingData: OnboardingData?) async throws -> (userId: String, isNewUser: Bool) {
        print("📱 Identifying user from receipt: \(originalTransactionId)")
        
        struct ReceiptRequest: Encodable {
            let originalTransactionId: String
            let onboardingData: OnboardingDataPayload?
            
            struct OnboardingDataPayload: Encodable {
                let name: String?
                let age: Int?
                let mood: String?
                let goal: String?
                let struggle: String?
                let preferredTime: String?
            }
        }
        
        struct ReceiptResponse: Decodable {
            let userId: String
            let isNewUser: Bool
            let userData: UserData?
            
            struct UserData: Decodable {
                let name: String?
                let age: Int?
                let goal: String?
                let main_struggle: String?
                let skill_level: String?
                let is_premium: Bool?
            }
        }
        
        let onboardingPayload = onboardingData.map { data in
            ReceiptRequest.OnboardingDataPayload(
                name: data.name,
                age: data.age,
                mood: data.mood,
                goal: data.goal,
                struggle: data.struggle,
                preferredTime: data.preferredTime
            )
        }
        
        let request = ReceiptRequest(
            originalTransactionId: originalTransactionId,
            onboardingData: onboardingPayload
        )
        
        let response: ReceiptResponse = try await client.functions.invoke(
            "identify-user-from-receipt",
            options: FunctionInvokeOptions(
                body: request
            )
        )
        
        // Store userId locally
        self.userId = response.userId
        self.isSignedIn = true
        
        let status = response.isNewUser ? "created" : "identified"
        print("✅ User \(status) from receipt. User ID: \(response.userId)")
        
        if let userData = response.userData {
            print("   Name: \(userData.name ?? "Unknown")")
            print("   Premium: \(userData.is_premium ?? false)")
        }
        
        return (userId: response.userId, isNewUser: response.isNewUser)
    }
    
    // MARK: - Email sign in / sign up


    struct BrainTwinUser: Codable {
        let id: String
        let email: String?  // ✅ Optional - can be null for receipt-based users
        let main_struggle: String?  // ✅ Optional - can be null for new users
        let rewire_progress: Double
        let current_streak: Int
        let skill_level: String?  // ✅ Optional - can be null for new users
        let onboarding_completed: Bool?
        let goal: String?
        let biggest_struggle: String?
        let preferred_time: String?
        let name: String?
        let age: Int?
        
        enum CodingKeys: String, CodingKey {
            case id, email, main_struggle, rewire_progress, current_streak, skill_level
            case onboarding_completed, goal, biggest_struggle, preferred_time, name, age
        }
    }


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
    
    // MARK: - Update User Name
    
    func updateUserName(name: String) async throws {
        guard let userId = userId else {
            throw NSError(
                domain: "SupabaseManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user ID found"]
            )
        }
        
        struct NameUpdate: Encodable {
            let name: String
        }
        
        let update = NameUpdate(name: name)
        
        try await client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()
        
        print("✅ User name updated to '\(name)' for user \(userId)")
    }
    
    // MARK: - Fetch User Name
    
    func fetchUserName() async throws -> String? {
        guard let userId = userId else {
            print("⚠️ No userId - cannot fetch name")
            return nil
        }
        
        do {
            let user: BrainTwinUser = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            print("✅ Fetched user name: '\(user.name ?? "nil")' for user \(userId)")
            return user.name
            
        } catch {
            print("❌ Error fetching user name: \(error)")
            return nil
        }
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
    
    // MARK: - Profile Picture Management
    
    /// Upload profile picture to Supabase Storage and save URL to database
    func uploadProfilePicture(_ image: UIImage) async throws -> String {
        guard let userId = userId else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID"])
        }
        
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        let fileName = "\(userId)/avatar.jpg"
        
        // Upload to Supabase Storage
        do {
            // Upload using Data directly (Supabase Swift SDK expects Data)
            _ = try await client.storage
                .from("profile-pictures")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
            
            print("✅ Profile picture uploaded: \(fileName)")
        } catch {
            print("❌ Upload error: \(error)")
            throw error
        }
        
        // Get public URL
        let publicURL = try client.storage
            .from("profile-pictures")
            .getPublicURL(path: fileName)
        
        let urlString = publicURL.absoluteString
        
        // Save URL to database
        try await client
            .from("users")
            .update(["profile_picture_url": urlString])
            .eq("id", value: userId)
            .execute()
        
        print("✅ Profile picture URL saved to database: \(urlString)")
        
        return urlString
    }
    
    /// Fetch profile picture URL from database
    func fetchProfilePictureURL() async throws -> String? {
        guard let userId = userId else { return nil }
        
        struct UserProfile: Decodable {
            let profile_picture_url: String?
        }
        
        let response: UserProfile = try await client
            .from("users")
            .select("profile_picture_url")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return response.profile_picture_url
    }
    
    /// Download profile picture from URL
    func downloadProfilePicture(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
}

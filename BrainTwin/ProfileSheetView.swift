import SwiftUI

struct ProfileSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var meterDataManager: MeterDataManager
    
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("profileImageData") private var profileImageData: Data?
    @State private var showSignOutAlert = false
    @State private var showSubscriptionView = false
    @State private var showImagePicker = false
    @State private var profileImage: UIImage?

    // Account deletion states
    @State private var showDeleteWarning = false
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeleting = false
    @State private var deletionDate: String?
    
    private var userId: String {
        SupabaseManager.shared.userId ?? "Unknown"
    }
    
    private var userInitial: String {
        userName.isEmpty ? "👤" : String(userName.prefix(1).uppercased())
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Profile Card
                        profileCard
                            .padding(.top, 20)
                        
                        // Menu Items
                        VStack(spacing: 0) {
                            menuItem(
                                icon: "crown.fill",
                                title: "Subscription",
                                iconColor: .appAccent,
                                action: { showSubscriptionView = true }
                            )

                            Divider()
                                .background(Color.appTextSecondary.opacity(0.2))
                                .padding(.horizontal, 20)

                            menuItem(
                                icon: "trash.fill",
                                title: "Delete Account",
                                iconColor: .red,
                                action: { showDeleteWarning = true }
                            )
                        }
                        .background(Color.appCardBackground)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Sign Out Button - Fixed at bottom
                Button {
                    showSignOutAlert = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20))
                        
                        Text("Sign Out")
                            .font(.headline)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.appCardBackground)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            // Load saved profile image
            if let imageData = profileImageData, let image = UIImage(data: imageData) {
                profileImage = image
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showDeleteConfirmation = true
            }
        } message: {
            Text("Your account will be scheduled for deletion in 14 days. You can cancel by signing back in within 14 days. All your data will be permanently deleted after the grace period.")
        }
        .alert("Confirm Deletion", isPresented: $showDeleteConfirmation) {
            TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }
            .disabled(deleteConfirmationText != "DELETE")
        } message: {
            Text("Type DELETE to permanently delete your account. This cannot be undone after 14 days.")
        }
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionManagementView()
        }
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker { image in
                // Save image locally first (for immediate display)
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    profileImageData = imageData
                    profileImage = image
                }
                
                // Upload to Supabase in background
                Task {
                    do {
                        let url = try await SupabaseManager.shared.uploadProfilePicture(image)
                        print("✅ Profile picture uploaded to Supabase: \(url)")
                    } catch {
                        print("❌ Failed to upload profile picture: \(error)")
                    }
                }
            }
        }
        .task {
            // Fetch profile picture from Supabase on app launch
            await fetchProfilePicture()
        }
    }
    
    // MARK: - Fetch Profile Picture
    
    private func fetchProfilePicture() async {
        do {
            // Check if we have a URL in the database
            if let urlString = try await SupabaseManager.shared.fetchProfilePictureURL() {
                print("📥 Fetching profile picture from: \(urlString)")
                
                // Download the image
                if let image = try await SupabaseManager.shared.downloadProfilePicture(from: urlString) {
                    // Save to local storage for offline access
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        profileImageData = imageData
                        profileImage = image
                        print("✅ Profile picture synced from backend")
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch profile picture: \(error)")
        }
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        VStack(spacing: 16) {
            // Profile Picture with Gradient - Tappable
            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .blur(radius: 20)
                        .opacity(0.6)
                    
                    if let profileImage = profileImage {
                        // Show selected image
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        // Show gradient circle with initial
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        // Initial or icon
                        Text(userInitial)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Edit button overlay
                    Circle()
                        .fill(Color.appCardBackground)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.appAccent)
                        )
                        .offset(x: 28, y: 28)
                }
            }
            .padding(.bottom, 8)
            
            // Name
            if !userName.isEmpty {
                Text(userName)
                    .font(.title2.bold())
                    .foregroundColor(.appTextPrimary)
            }
            
            // User ID
            Text(userId.prefix(8) + "...")
                .font(.caption)
                .foregroundColor(.appTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appCardBackground)
                .cornerRadius(8)
            
            // Stats Row
            HStack(spacing: 24) {
                statItem(
                    value: "\(meterDataManager.meterData?.streak ?? 0)",
                    label: "Day Streak",
                    icon: "🔥"
                )
                
                Divider()
                    .frame(height: 30)
                
                statItem(
                    value: "\(Int(meterDataManager.meterData?.progress ?? 0))%",
                    label: "Rewired",
                    icon: "⚡"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appCardBackground)
            )
        }
    }
    
    // MARK: - Stat Item
    
    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 16))
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.appTextPrimary)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Menu Item
    
    private func menuItem(icon: String, title: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.appTextPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
    }
    
    // MARK: - Sign Out

    private func signOut() {
        Task {
            do {
                try await SupabaseManager.shared.signOut()
                dismiss()
            } catch {
                print("❌ Sign out error: \(error)")
            }
        }
    }

    // MARK: - Delete Account

    private func deleteAccount() {
        guard deleteConfirmationText == "DELETE" else {
            print("⚠️ Delete confirmation text mismatch")
            return
        }

        isDeleting = true

        Task {
            do {
                let response = try await SupabaseManager.shared.requestAccountDeletion()
                print("✅ Account deletion requested successfully")

                // Format deletion date for display
                let dateFormatter = ISO8601DateFormatter()
                if let date = dateFormatter.date(from: response.deletionDate) {
                    let displayFormatter = DateFormatter()
                    displayFormatter.dateStyle = .long
                    displayFormatter.timeStyle = .none
                    deletionDate = displayFormatter.string(from: date)
                }

                // Reset confirmation text
                deleteConfirmationText = ""
                isDeleting = false

                // Sign out user
                try await SupabaseManager.shared.signOut()
                dismiss()

            } catch {
                print("❌ Account deletion error: \(error)")
                deleteConfirmationText = ""
                isDeleting = false

                // Show error to user (optional - you can add error alert if needed)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileSheetView()
        .environmentObject(MeterDataManager.shared)
}

import SwiftUI

struct AccountView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @State private var userProgress: Double = 0
    @State private var daysActive: Int = 0
    @State private var showImagePicker = false
    @State private var avatarImage: UIImage?
    @State private var showSubscription = false
    @State private var showBrainProgress = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with Profile Avatar and Name
                VStack(spacing: 12) {
                    Button {
                        showImagePicker = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            if let image = avatarImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Text(getInitials())
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            // Small edit indicator
                            Circle()
                                .fill(Color.gray.opacity(0.9))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    
                    Text(getUserName())
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    if let userId = supabase.userId {
                        Text(String(userId.prefix(12)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
                
                // Brain Rewiring Progress Card
                Button {
                    showBrainProgress = true
                } label: {
                    HStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        
                        Text("Brain Rewiring Progress")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // Days Active Card
                Button {
                    // Handle tap
                } label: {
                    HStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Days Active")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text("\(daysActive) days since you started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // Subscription Card
                Button {
                    showSubscription = true
                } label: {
                    HStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow)
                        }
                        
                        Text("Subscription")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // About Card
                Button {
                    // Handle about
                } label: {
                    HStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                        }
                        
                        Text("About")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // Account/Sign Out Card
                Button {
                    Task {
                        if supabase.isSignedIn {
                            try? await supabase.signOut()
                        } else {
                            try? await supabase.signInAnonymously()
                        }
                    }
                } label: {
                    HStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill((supabase.isSignedIn ? Color.red : Color.green).opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: supabase.isSignedIn ? "rectangle.portrait.and.arrow.right.fill" : "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(supabase.isSignedIn ? .red : .green)
                        }
                        
                        Text(supabase.isSignedIn ? "Sign Out" : "Login")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 30)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGray6))
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadUserProgress()
            await loadDaysActive()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $avatarImage)
        }
        .navigationDestination(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showBrainProgress) {
            BrainProgressDetailView(progress: userProgress)
                .presentationDetents([.medium])
        }
    }
    
    private func getUserName() -> String {
        if let userId = supabase.userId {
            return "User \(userId.prefix(8))"
        }
        return "Guest"
    }
    
    private func getInitials() -> String {
        if let userId = supabase.userId {
            return String(userId.prefix(1)).uppercased()
        }
        return "G"
    }
    
    private func loadUserProgress() async {
        guard let userId = supabase.userId else { return }
        
        do {
            let meterData: MeterResponse = try await supabase.getMeterData(userId: userId)
            userProgress = meterData.progress
        } catch {
            print("âŒ Load progress error: \(error)")
        }
    }
    
    private func loadDaysActive() async {
        // TODO: Load actual days active from your backend
        // For now using placeholder value
        daysActive = 0
    }
}

// MARK: - Brain Progress Detail View
struct BrainProgressDetailView: View {
    let progress: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Brain Rewiring Progress")
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Progress Circle
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 15)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0, to: progress / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow, Color.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(Int(progress))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical)
            
            // Description
            VStack(spacing: 12) {
                Text("Your brain is being rewired!")
                    .font(.headline)
                
                Text("Keep completing daily hacks and protocols to strengthen new neural pathways and build lasting habits.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Account Menu Item
struct AccountMenuItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with background circle
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }
}

// Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}

#Preview {
    AccountView()
}

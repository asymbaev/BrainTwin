import SwiftUI

struct AccountView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @State private var userProgress: Double = 0
    @State private var showImagePicker = false
    @State private var avatarImage: UIImage?
    @State private var showSubscription = false

    
    var body: some View {
        ZStack {
            // Same gradient as other pages
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.1, blue: 0.35),
                    Color(red: 0.08, green: 0.05, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with Avatar
                    HStack {
                        Spacer()
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            ZStack {
                                if let image = avatarImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.yellow)
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Text(getInitials())
                                                .font(.title.bold())
                                                .foregroundColor(.black)
                                        )
                                }
                                
                                // Edit icon
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 28, y: 28)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    
                    // User name
                    Text(getUserName())
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    // Brain Rewiring Progress Card
                    VStack(spacing: 16) {
                        Text("Brain Rewired")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 15)
                                .frame(width: 150, height: 150)
                            
                            Circle()
                                .trim(from: 0, to: userProgress / 100)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                                )
                                .frame(width: 150, height: 150)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1.0), value: userProgress)
                            
                            VStack(spacing: 4) {
                                Text("\(Int(userProgress))%")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Since signup")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 20)
                    
                    Button {
                        showSubscription = true
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Subscription")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $showSubscription) {
                        SubscriptionView()
                            .presentationDetents([.large])  // Only large size
                    }
                    // Sign Out / Login Button
                    if supabase.isSignedIn {
                        Button {
                            Task {
                                try? await supabase.signOut()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    } else {
                        Button {
                            Task {
                                try? await supabase.signInAnonymously()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.green)
                                Text("Login")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // About Button
                    Button {
                        // Handle about
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("About")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 40)
                }
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .task {
            await loadUserProgress()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $avatarImage)
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
            print("❌ Load progress error: \(error)")
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

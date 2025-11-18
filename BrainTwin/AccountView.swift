import SwiftUI

struct AccountView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var showImagePicker = false
    @State private var avatarImage: UIImage?
    @State private var showSubscription = false
    
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
    
    // Make the grounding visually obvious
    private let groundingHeight: CGFloat = 88

    var body: some View {
        ZStack {
            // Background
            Color.appBackground.ignoresSafeArea()
            if colorScheme == .dark {
                RadialGradient(
                    colors: [Color(white: 0.04), .black],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
            
            // CONTENT
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Header (avatar + identity)
                    VStack(spacing: 8) {
                        Button { showImagePicker = true } label: {
                            ZStack(alignment: .bottomTrailing) {
                                if let image = avatarImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.appAccent)
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Text(getInitials())
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundColor(colorScheme == .dark ? .black : .white)
                                        )
                                }
                                Circle()
                                    .fill(Color.appTextSecondary.opacity(0.92))
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 10.5, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.appBackground, lineWidth: 2))
                                    .offset(x: 2, y: 2)
                            }
                        }
                        
                        Text(getUserName())
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appTextPrimary)
                        
                        if let userId = supabase.userId {
                            Text(String(userId.prefix(12)))
                                .font(.footnote)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .overlay(
                        Divider()
                            .background(Color.appCardBorder)
                            .padding(.top, 96),
                        alignment: .bottom
                    )
                    
                    // MARK: - APP Section
                    InsetSectionHeader(title: "APP")
                        .padding(.horizontal, 20)
                    InsetSection {
                        SettingsRow(
                            icon: "crown.fill",
                            title: "Subscription",
                            subtitle: nil,
                            tint: Color.appAccent,
                            showChevron: true
                        ) {
                            showSubscription = true
                        }
                        SettingsDivider()
                        SettingsRow(
                            icon: "info.circle",
                            title: "About",
                            subtitle: nil,
                            tint: .appTextSecondary,
                            showChevron: true
                        ) {
                            // TODO
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - ACCOUNT Section
                    InsetSectionHeader(title: "ACCOUNT")
                        .padding(.horizontal, 20)
                    InsetSection {
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: supabase.isSignedIn ? "Sign Out" : "Login",
                            subtitle: nil,
                            tint: .red,
                            showChevron: false,
                            destructive: true
                        ) {
                            Task {
                                if supabase.isSignedIn {
                                    try? await supabase.signOut()
                                } else {
                                    try? await supabase.signInAnonymously()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                // Exact space so the last row sits nicely above the bar
                .padding(.bottom, groundingHeight + 12)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $avatarImage)
        }
        .navigationDestination(isPresented: $showSubscription) {
            SubscriptionView()
        }
        // ⚡️ Strong, obvious grounding at the bottom — blur + gradient + top separator
        .overlay(alignment: .bottom) {
            BottomGroundingBar(height: groundingHeight)
                .allowsHitTesting(false) // never block tab bar interactions
                .ignoresSafeArea(edges: .bottom)
        }
    }
    
    // MARK: Helpers
    private func getUserName() -> String {
        if let userId = supabase.userId { "User \(userId.prefix(8))" } else { "Guest" }
    }
    private func getInitials() -> String {
        if let userId = supabase.userId { String(userId.prefix(1)).uppercased() } else { "G" }
    }
}

// MARK: - Bottom blur + gradient grounding
private struct BottomGroundingBar: View {
    @Environment(\.colorScheme) var colorScheme
    let height: CGFloat
    
    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let v = (info?["CFBundleShortVersionString"] as? String) ?? "-"
        let b = (info?["CFBundleVersion"] as? String) ?? "-"
        return "BrainTwin v\(v) (\(b))"
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Blur base
            Rectangle()
                .fill(.regularMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            (colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.14)),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .mask(
                    LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.7), Color.black.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            
            // Subtle separator at the top edge of the bar
            Rectangle()
                .fill(Color.appCardBorder.opacity(0.8))
                .frame(height: 0.6)
                .padding(.horizontal, 16)
                .padding(.top, 0)
            
            // Version label (optional; remove if you want pure visual weight)
            VStack {
                Spacer()
                Text(versionString)
                    .font(.footnote)
                    .foregroundColor(.appTextSecondary)
                    .padding(.bottom, 8)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Inset Section Components

private struct InsetSectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appTextSecondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

private struct InsetSection<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.vertical, 4)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.appCardBorder.opacity(colorScheme == .dark ? 0.35 : 0.18), lineWidth: 0.5)
            )
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(Color.appCardBorder)
            .padding(.leading, 28)
    }
}

private struct SettingsRow: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let tint: Color
    let showChevron: Bool
    var destructive: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(destructive ? .red : tint)
                        .frame(width: 18, height: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(destructive ? .red : .appTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                    }
                }
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextSecondary)
                }
            }
            .frame(height: 56)
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image Picker (unchanged)
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
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
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

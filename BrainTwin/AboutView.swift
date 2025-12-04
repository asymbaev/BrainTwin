import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // App Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .blur(radius: 20)
                                .opacity(0.6)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 92, height: 92)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        // App Info
                        VStack(spacing: 8) {
                            Text("BrainTwin")
                                .font(.title.bold())
                                .foregroundColor(.appTextPrimary)
                            
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.subheadline)
                                .foregroundColor(.appTextSecondary)
                        }
                        
                        // Links Section
                        VStack(spacing: 0) {
                            linkItem(
                                icon: "doc.text.fill",
                                title: "Privacy Policy",
                                url: "https://braintwin.app/privacy"
                            )
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            linkItem(
                                icon: "doc.plaintext.fill",
                                title: "Terms of Service",
                                url: "https://braintwin.app/terms"
                            )
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            linkItem(
                                icon: "envelope.fill",
                                title: "Contact Support",
                                url: "mailto:support@braintwin.app"
                            )
                        }
                        .background(Color.appCardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        // Copyright
                        Text("© 2025 BrainTwin")
                            .font(.caption)
                            .foregroundColor(.appTextSecondary.opacity(0.6))
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("About")
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
        }
    }
    
    // MARK: - Link Item
    
    private func linkItem(icon: String, title: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.appAccent)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.appTextPrimary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    AboutView()
}

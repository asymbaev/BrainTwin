import SwiftUI

struct SubscriptionManagementView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()
                
                // Subtle gradient overlay (only in dark mode)
                if colorScheme == .dark {
                    RadialGradient(
                        colors: [
                            Color(white: 0.04),
                            Color.black
                        ],
                        center: .top,
                        startRadius: 0,
                        endRadius: 500
                    )
                    .ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Crown Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
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
                                .frame(width: 72, height: 72)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        // Title
                        VStack(spacing: 8) {
                            Text("Premium Subscription")
                                .font(.title.bold())
                                .foregroundColor(.appTextPrimary)
                            
                            Text("You're on the premium plan")
                                .font(.subheadline)
                                .foregroundColor(.appTextSecondary)
                        }
                        
                        // Subscription Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("BrainTwin Premium")
                                        .font(.headline)
                                        .foregroundColor(.appTextPrimary)
                                    
                                    Text("Yearly Plan")
                                        .font(.subheadline)
                                        .foregroundColor(.appTextSecondary)
                                }
                                
                                Spacer()
                                
                                Text("$29.99/yr")
                                    .font(.title3.bold())
                                    .foregroundColor(.appAccent)
                            }
                            
                            Divider()
                            
                            // Features
                            featureRow(icon: "checkmark.circle.fill", text: "Unlimited AI Brain Hacks")
                            featureRow(icon: "checkmark.circle.fill", text: "Personalized Rewiring Plan")
                            featureRow(icon: "checkmark.circle.fill", text: "Advanced Progress Tracking")
                            featureRow(icon: "checkmark.circle.fill", text: "Priority Support")
                        }
                        .padding(20)
                        .background(Color.appCardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.appCardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Manage Subscription Button
                        Button {
                            openSubscriptionManagement()
                        } label: {
                            Text("Manage Subscription")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 20)
                        
                        // Restore Purchases Button
                        Button {
                            restorePurchases()
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Subscription")
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
    
    // MARK: - Feature Row
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.appAccent)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.appTextPrimary)
        }
    }
    
    // MARK: - Actions
    
    private func openSubscriptionManagement() {
        // Open iOS subscription management
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func restorePurchases() {
        Task {
            await SubscriptionManager.shared.refreshSubscription()
        }
    }
}

#Preview {
    SubscriptionManagementView()
}

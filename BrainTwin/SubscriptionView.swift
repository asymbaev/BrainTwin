import SwiftUI

struct SubscriptionView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // ✅ Appearance override (same as DailyHackView)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var showMembershipDetails = false
    @State private var currentPlan: PremiumPlan = .monthly // Default, will fetch from backend
    
    // ✅ Computed color scheme based on user preference
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System
        }
    }
    
    var body: some View {
        ZStack {
            // ✅ Adaptive background (same as DailyHackView pages 2-3)
            Color.appBackground.ignoresSafeArea()
            
            // ✅ Subtle depth gradient (only in dark mode)
            if colorScheme == .dark {
                RadialGradient(
                    colors: [
                        Color(white: 0.04),
                        Color.black
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Card Container with both items
                    VStack(spacing: 0) {
                        // Membership Row
                        Button {
                            showMembershipDetails = true
                        } label: {
                            HStack(spacing: 16) {
                                // Icon
                                Image(systemName: "person.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.appTextSecondary)
                                    .frame(width: 28)
                                
                                Text("Membership")
                                    .font(.body)
                                    .foregroundColor(.appTextPrimary)
                                
                                Spacer()
                                
                                Text("Premium")
                                    .font(.body)
                                    .foregroundColor(.appTextSecondary)
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        
                        Divider()
                            .background(Color.appCardBorder)
                            .padding(.leading, 60)
                        
                        // Change Premium Plan Row
                        Button {
                            showMembershipDetails = true
                        } label: {
                            HStack(spacing: 16) {
                                // Icon
                                Image(systemName: "infinity")
                                    .font(.system(size: 22))
                                    .foregroundColor(.appTextSecondary)
                                    .frame(width: 28)
                                
                                Text("Change Premium Plan")
                                    .font(.body)
                                    .foregroundColor(.appTextPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.appTextSecondary)
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                    }
                    .background(Color.appCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appCardBorder, lineWidth: 1)
                    )
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.large)
        // ✅ Apply user's preferred color scheme
        .preferredColorScheme(preferredColorScheme)
        .navigationDestination(isPresented: $showMembershipDetails) {
            MembershipDetailsView(currentPlan: $currentPlan)
        }
    }
}

enum PremiumPlan: String, CaseIterable, Equatable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    
    var price: String {
        switch self {
        case .weekly: return "$5.99"
        case .monthly: return "$12.99"
        case .yearly: return "$59.99"
        }
    }
    
    var pricePerWeek: String {
        switch self {
        case .weekly: return "$5.99 per week"
        case .monthly: return "$2.99 per week"
        case .yearly: return "$1.15 per week"
        }
    }
    
    var billingCycle: String {
        switch self {
        case .weekly: return "per week"
        case .monthly: return "per month"
        case .yearly: return "per year"
        }
    }
    
    var billingFrequency: String {
        switch self {
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .yearly: return "yearly"
        }
    }
    
    var savings: String? {
        switch self {
        case .weekly: return nil
        case .monthly: return "SAVE 40%"
        case .yearly: return "SAVE 77%"
        }
    }
}

#Preview {
    SubscriptionView()
}

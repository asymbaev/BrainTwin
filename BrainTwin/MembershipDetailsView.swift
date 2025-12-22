import SwiftUI

struct MembershipDetailsView: View {
    @Binding var currentPlan: PremiumPlan
    @Environment(\.colorScheme) var colorScheme
    
    // ✅ Appearance override (same as DailyHackView)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var selectedPlan: PremiumPlan
    
    // ✅ Computed color scheme based on user preference
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System
        }
    }
    
    init(currentPlan: Binding<PremiumPlan>) {
        self._currentPlan = currentPlan
        self._selectedPlan = State(initialValue: currentPlan.wrappedValue)
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
                VStack(spacing: 24) {
                    // Title with Premium in gold
                    HStack(spacing: 0) {
                        Text("Manage your ")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        Text("Premium")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.appAccent)
                    }
                    .padding(.top, 20)
                    
                    // Crown icon
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.appAccent)
                        .padding(.vertical, 8)
                    
                    // Active Plan Label
                    Text("ACTIVE PLAN")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appTextSecondary)
                        .tracking(1)
                        .padding(.top, 8)
                    
                    // Current Active Plan Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(currentPlan.rawValue) Access")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.appTextPrimary)
                        
                        Text("\(currentPlan.price) per week")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.appCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.appCardBorder, lineWidth: 2)
                    )
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // Other Options Label
                    Text("OTHER OPTIONS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appTextSecondary)
                        .tracking(1)
                        .padding(.top, 16)
                    
                    // Other Plan Options
                    VStack(spacing: 16) {
                        ForEach(PremiumPlan.allCases.filter { $0 != currentPlan }, id: \.self) { plan in
                            PlanOptionCard(
                                plan: plan,
                                isSelected: selectedPlan == plan,
                                onTap: {
                                    selectedPlan = plan
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Confirm Button
                    Button {
                        // Handle plan change
                        currentPlan = selectedPlan
                    } label: {
                        HStack {
                            Text("Confirm")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                        }
                        .padding()
                        .background(Color.appAccent)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Terms and Privacy
                    HStack(spacing: 16) {
                        Button("Terms of use") {
                            if let url = URL(string: "https://asymbaev.github.io/neurohack-legal/terms.html") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                        
                        Button("Privacy policy") {
                            if let url = URL(string: "https://asymbaev.github.io/neurohack-legal/privacy.html") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Membership")
        .navigationBarTitleDisplayMode(.inline)
        // ✅ Apply user's preferred color scheme
        .preferredColorScheme(preferredColorScheme)
    }
}

// Plan Option Card Component - ADAPTIVE
struct PlanOptionCard: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(plan.rawValue) Access")
                        .font(.headline)
                        .foregroundColor(.appTextPrimary)
                    
                    Text(plan.pricePerWeek)
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                    
                    Text("billed \(plan.billingFrequency) at \(plan.price)")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                if let savings = plan.savings {
                    Text(savings)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(20)
                }
            }
            .padding(20)
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.blue : Color.appCardBorder, lineWidth: 2)
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MembershipDetailsView(currentPlan: .constant(.monthly))
}

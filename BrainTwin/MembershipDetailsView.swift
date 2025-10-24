import SwiftUI

struct MembershipDetailsView: View {
    @Binding var currentPlan: PremiumPlan
    @State private var selectedPlan: PremiumPlan
    
    init(currentPlan: Binding<PremiumPlan>) {
        self._currentPlan = currentPlan
        self._selectedPlan = State(initialValue: currentPlan.wrappedValue)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title with Premium in gold
                HStack(spacing: 0) {
                    Text("Manage your ")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Premium")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                }
                .padding(.top, 20)
                
                // Crown icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                    .padding(.vertical, 8)
                
                // Active Plan Label
                Text("ACTIVE PLAN")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .padding(.top, 8)
                
                // Current Active Plan Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(currentPlan.rawValue) Access")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(currentPlan.price) per week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                        .background(Color(.systemBackground))
                )
                .cornerRadius(16)
                .padding(.horizontal, 20)
                
                // Other Options Label
                Text("OTHER OPTIONS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
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
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.secondary)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button("Terms of use") {
                        // Handle terms tap
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Button("Privacy policy") {
                        // Handle privacy tap
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.93))
        .navigationTitle("Membership")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Plan Option Card Component
struct PlanOptionCard: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(plan.rawValue) Access")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(plan.pricePerWeek)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("billed \(plan.billingFrequency) at \(plan.price)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let savings = plan.savings {
                    Text(savings)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 1.0, green: 0.4, blue: 0.4))
                        .cornerRadius(20)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MembershipDetailsView(currentPlan: .constant(.monthly))
}

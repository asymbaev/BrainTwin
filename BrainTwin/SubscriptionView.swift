import SwiftUI

struct SubscriptionView: View {
    @State private var showMembershipDetails = false
    @State private var currentPlan: PremiumPlan = .monthly // Default, will fetch from backend
    
    var body: some View {
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
                                .foregroundColor(.secondary)
                                .frame(width: 28)
                            
                            Text("Membership")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("Premium")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    // Change Premium Plan Row
                    Button {
                        showMembershipDetails = true
                    } label: {
                        HStack(spacing: 16) {
                            // Icon
                            Image(systemName: "infinity")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                                .frame(width: 28)
                            
                            Text("Change Premium Plan")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGray6))
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.large)
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

import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showMembershipDetails = false
    @State private var showChangePlan = false
    @State private var currentPlan: PremiumPlan = .monthly // Default, will fetch from backend
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Membership Button
                            Button {
                                showMembershipDetails = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.white)
                                    
                                    Text("Membership")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("Premium")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.yellow)
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            // Change Premium Plan Button
                            Button {
                                showChangePlan = true
                            } label: {
                                HStack {
                                    Image(systemName: "infinity")
                                        .foregroundColor(.white)
                                    
                                    Text("Change Premium Plan")
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
                        }
                        .padding(.top, 8)  // Minimal top padding
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
            .sheet(isPresented: $showMembershipDetails) {
                MembershipDetailsView(currentPlan: $currentPlan)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showChangePlan) {
                ChangePlanView(currentPlan: $currentPlan)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

enum PremiumPlan: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    
    var price: String {
        switch self {
        case .weekly: return "$4.99"
        case .monthly: return "$14.99"
        case .yearly: return "$99.99"
        }
    }
    
    var billingCycle: String {
        switch self {
        case .weekly: return "per week"
        case .monthly: return "per month"
        case .yearly: return "per year"
        }
    }
    
    var savings: String? {
        switch self {
        case .weekly: return nil
        case .monthly: return "Save 25%"
        case .yearly: return "Save 50%"
        }
    }
}

#Preview {
    SubscriptionView()
}

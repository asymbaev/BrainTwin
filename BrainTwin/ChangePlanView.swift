import SwiftUI

struct ChangePlanView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var currentPlan: PremiumPlan
    @State private var selectedPlan: PremiumPlan
    
    init(currentPlan: Binding<PremiumPlan>) {
        self._currentPlan = currentPlan
        self._selectedPlan = State(initialValue: currentPlan.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.1, blue: 0.35),
                    Color(red: 0.08, green: 0.05, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Change Plan")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Choose your premium plan")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.top, 30)
                        
                        Text("All plans include full access to premium features")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Plan Cards
                        ForEach(PremiumPlan.allCases, id: \.self) { plan in
                            PlanCard(
                                plan: plan,
                                isSelected: selectedPlan == plan,
                                isCurrent: currentPlan == plan
                            ) {
                                selectedPlan = plan
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Confirm Button
                        if selectedPlan != currentPlan {
                            Button {
                                currentPlan = selectedPlan
                                dismiss()
                            } label: {
                                Text("Switch to \(selectedPlan.rawValue)")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.yellow)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                        
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct PlanCard: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let isCurrent: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.rawValue)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            
                            if isCurrent {
                                Text("Current")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(6)
                            }
                        }
                        
                        if let savings = plan.savings {
                            Text(savings)
                                .font(.caption.bold())
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(plan.price)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text(plan.billingCycle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                if isSelected && !isCurrent {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.yellow)
                        Text("Selected")
                            .font(.subheadline.bold())
                            .foregroundColor(.yellow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
            }
            .padding()
            .background(
                isSelected
                    ? Color.yellow.opacity(0.2)
                    : Color.white.opacity(0.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
    }
}

#Preview {
    ChangePlanView(currentPlan: .constant(.monthly))
}

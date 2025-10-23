import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Binding var isOnboardingComplete: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= viewModel.currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding()
            
            // Content
            TabView(selection: $viewModel.currentStep) {
                welcomeView.tag(0)
                goalView.tag(1)
                readyView.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
    
    // MARK: - Step 1: Welcome
    
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("🧠")
                .font(.system(size: 100))
            
            Text("Meet Your Brain Twin")
                .font(.largeTitle.bold())
            
            Text("An AI neuroscience coach that learns your patterns and helps you rewire your brain for peak performance.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button("Get Started") {
                withAnimation {
                    viewModel.currentStep = 1
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
    }
    
    // MARK: - Step 2: Goal Collection
    
    private var goalView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What's your main goal?")
                    .font(.title2.bold())
                
                Text("This becomes the foundation for your daily brain rewiring.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Goal input
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Goal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("e.g., Build discipline to finish my startup tasks", text: $viewModel.mainGoal, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .lineLimit(3...6)
            }
            .padding(.horizontal)
            
            // Quick suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("Popular goals:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.suggestedGoals, id: \.self) { goal in
                            Button {
                                viewModel.mainGoal = goal
                            } label: {
                                Text(goal)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            Button("Continue") {
                Task {
                    await viewModel.saveGoal()
                    // Animation handled in View, not ViewModel
                    withAnimation {
                        // currentStep is already updated by ViewModel
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.mainGoal.count < 10)
            .padding()
        }
    }
    
    // MARK: - Step 3: Ready
    
    private var readyView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("🎯")
                .font(.system(size: 100))
            
            Text("You're All Set!")
                .font(.largeTitle.bold())
            
            VStack(spacing: 16) {
                Text("Every day, I'll:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    CheckItem(text: "Ask about your daily task")
                    CheckItem(text: "Generate personalized brain hacks")
                    CheckItem(text: "Track your rewiring progress")
                    CheckItem(text: "Learn and adapt to your patterns")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
            
            Button("Start My Journey") {
                withAnimation {
                    isOnboardingComplete = true
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
    }
}

struct CheckItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(16)
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}

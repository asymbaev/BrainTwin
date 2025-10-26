import SwiftUI

struct DailyCheckInView: View {
    let onContinue: () -> Void  // ← NEW: Callback instead of dismiss
    @State private var userResponse: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Top bar with Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        onContinue()  // ← CHANGED: Call callback
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
                
                // Main content
                VStack(spacing: 16) {
                    Text("💭")
                        .font(.system(size: 60))
                    
                    Text("How did you apply yesterday's hack?")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text("Share your experience to get personalized feedback")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Text input area
                VStack(spacing: 12) {
                    TextEditor(text: $userResponse)
                        .focused($isTextFieldFocused)
                        .frame(height: 150)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                    
                    // Continue button (only show if user typed something)
                    if !userResponse.isEmpty {
                        Button {
                            onContinue()  // ← CHANGED: Call callback
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Auto-focus text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

#Preview {
    DailyCheckInView(onContinue: {
        print("Continue tapped")
    })
}

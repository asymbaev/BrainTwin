import SwiftUI
import os

struct DailyCheckInView: View {
    let onContinue: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    // ✅ Appearance override (same as DailyHackView)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var userResponse: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var cloudOffset: CGFloat = 0
    
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
            
            VStack(spacing: 0) {
                // ✅ Premium top bar with Skip button
                HStack {
                    Spacer()
                    
                    Button {
                        onContinue()
                    } label: {
                        Text("Skip")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.appCardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.appCardBorder, lineWidth: 1)
                            )
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // ✅ Main content with floating cloud
                VStack(spacing: 24) {
                    // Animated cloud icon
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Text("💭")
                            .font(.system(size: 50))
                            .offset(y: cloudOffset)
                            .onAppear {
                                withAnimation(
                                    .easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true)
                                ) {
                                    cloudOffset = -8
                                }
                            }
                    }
                    .padding(.bottom, 8)
                    
                    // Title
                    Text("How did you apply yesterday's hack?")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                    
                    // Subtitle
                    Text("Share your experience to get personalized feedback")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // ✅ Auto-expanding TextField (Option 1)
                VStack(spacing: 16) {
                    // Single-line TextField that expands as user types
                    TextField("I applied the hack when...", text: $userResponse, axis: .vertical)
                        .focused($isTextFieldFocused)
                        .font(.body)
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1...4)  // Starts at 1 line, expands to max 4 lines
                        .padding(16)
                        .background(Color.appCardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isTextFieldFocused ? Color.appAccent.opacity(0.5) : Color.appCardBorder,
                                    lineWidth: isTextFieldFocused ? 2 : 1
                                )
                        )
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
                    
                    // ✅ Premium Continue button (shows when user types)
                    if !userResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            saveCheckInResponse()
                            onContinue()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                
                                Image(systemName: "arrow.right")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.appAccent)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: userResponse.isEmpty)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        // ✅ Apply user's preferred color scheme
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            // Auto-focus text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }

    // Save check-in response to UserDefaults for reflection history
    private func saveCheckInResponse() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: Date())

        // Save to UserDefaults with date as key
        let key = "checkIn_\(dateKey)"
        UserDefaults.standard.set(userResponse, forKey: key)

        print("💭 Saved check-in response for \(dateKey): \(userResponse)")
    }
}

#Preview {
    DailyCheckInView(onContinue: {
        print("Continue tapped")
    })
}

import SwiftUI
import UIKit

// MARK: - Profile Setup Loading Screen (Post-Purchase)
struct ThankYouView: View {
    var onContinue: () -> Void

    @State private var progress: Double = 0
    @State private var currentMessage = ""
    @State private var showButton = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    private let messages = [
        "Setting up your profile...",
        "Preparing your personalized plan...",
        "Getting everything ready..."
    ]

    // Computed color scheme
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            // ✅ Adaptive background
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
                Spacer()

                // Motivational header
                Text("Congrats!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.appTextPrimary)
                    .padding(.bottom, 8)

                Text("You're one step closer to reaching\nyour prime and becoming superhuman")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)

                if !showButton {
                    // Lightning icon
                    Text("⚡")
                        .font(.system(size: 64))
                        .padding(.bottom, 32)

                    // Status message
                    Text(currentMessage)
                        .font(.title3.weight(.medium))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(height: 60)
                        .padding(.horizontal, 40)
                        .animation(.easeInOut(duration: 0.3), value: currentMessage)

                    Spacer()
                        .frame(height: 40)

                    // Percentage
                    Text("\(Int(progress))%")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .monospacedDigit()
                        .padding(.bottom, 24)

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appCardBorder)
                                .frame(height: 8)

                            // Filled progress
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appAccentGradient)
                                .frame(width: geometry.size.width * (progress / 100), height: 8)
                                .animation(.linear(duration: 0.5), value: progress)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 40)
                } else {
                    // Success state
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.appAccent)
                            .shadow(color: colorScheme == .dark ? Color.appAccent.opacity(0.4) : .clear, radius: 12)
                    }
                    .padding(.bottom, 24)

                    Text("All set!")
                        .font(.title2.bold())
                        .foregroundColor(.appTextPrimary)
                        .padding(.bottom, 48)

                    // Rewire button
                    Button(action: onContinue) {
                        Text("Start Rewiring")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.appAccent)
                            .cornerRadius(16)
                            .shadow(color: Color.appAccent.opacity(0.3), radius: 12)
                            .padding(.horizontal, 28)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            startLoadingAnimation()

            // ✅ PRE-FETCH: Load data during animation so dashboard appears instantly
            Task {
                print("🚀 [ThankYou] Pre-fetching data during animation...")
                await MeterDataManager.shared.fetchMeterData(force: true)
                print("✅ [ThankYou] Data ready! Dashboard will load instantly.")
            }
        }
    }

    private func startLoadingAnimation() {
        // Message 1: "Setting up your profile..." (0-33%)
        currentMessage = messages[0]

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if progress < 33 {
                progress += 1
            } else if progress < 34 {
                // Switch to message 2
                currentMessage = messages[1]
                progress += 1
            } else if progress < 66 {
                progress += 1
            } else if progress < 67 {
                // Switch to message 3
                currentMessage = messages[2]
                progress += 1
            } else if progress < 100 {
                progress += 1
            } else {
                timer.invalidate()
                // Show success state with button
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showButton = true
                    }
                }
            }
        }
    }
}

#Preview {
    ThankYouView {
        print("Continue tapped")
    }
}


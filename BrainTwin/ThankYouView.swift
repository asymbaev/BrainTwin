import SwiftUI
import UIKit

// MARK: - Profile Setup Loading Screen (Post-Purchase)
struct ThankYouView: View {
    var onContinue: () -> Void

    @State private var progress: Double = 0
    @State private var currentMessage = ""
    @State private var showButton = false
    @State private var isDashboardReady = false
    @State private var isPulsing = false  // ✅ For 99% pulse animation
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    private let messages = [
        "Setting up your profile...",
        "Preparing your personalized plan...",
        "Getting everything ready...",
        "Loading your dashboard...",
        "Almost there..."  // ✅ NEW: Shows at 99%
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

                    // Percentage (with pulse at 99%)
                    Text("\(Int(progress))%")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .monospacedDigit()
                        .padding(.bottom, 24)
                        .scaleEffect(isPulsing ? 1.05 : 1.0)  // ✅ Subtle pulse at 99%
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)

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

            // ✅ PRE-FETCH: Load data during animation and wait until ready
            Task {
                print("🚀 [ThankYou] Checking if hack is already pre-generated...")

                // ✅ CRITICAL: Check if user exists first!
                guard SupabaseManager.shared.userId != nil else {
                    print("⚠️ [ThankYou] NO USER ID - Cannot fetch data!")
                    print("   This should NOT happen - user should have been created after purchase")
                    print("   Marking dashboard as 'ready' to unblock UI...")

                    // Wait a bit to let user creation complete
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

                    // Check again
                    if SupabaseManager.shared.userId == nil {
                        print("❌ [ThankYou] Still no user ID after 3s - something is very wrong!")
                        print("   Proceeding anyway to avoid infinite loading...")
                    }

                    await MainActor.run {
                        isDashboardReady = true
                    }
                    return
                }

                print("✅ [ThankYou] User ID exists: \(SupabaseManager.shared.userId!)")

                // Check if hack is already loaded from background generation
                if MeterDataManager.shared.todaysHack == nil {
                    print("⏳ [ThankYou] Hack not ready yet, fetching now...")
                    await MeterDataManager.shared.fetchMeterData(force: true)
                } else {
                    print("✅ [ThankYou] Hack already pre-generated! Skipping fetch.")
                }

                // ✅ CRITICAL: Pre-download audio files if not already cached
                if let audioUrls = MeterDataManager.shared.todaysHack?.audioUrls, !audioUrls.isEmpty {
                    print("🎵 [ThankYou] Ensuring \(audioUrls.count) audio files are cached...")
                    await AudioCacheManager.shared.preDownloadAudioFiles(audioUrls)
                    print("✅ [ThankYou] Audio files ready - Listen will be INSTANT!")
                }

                // Verify data is actually loaded
                if MeterDataManager.shared.meterData != nil {
                    print("✅ [ThankYou] Dashboard data confirmed ready!")
                    await MainActor.run {
                        isDashboardReady = true
                    }
                } else {
                    print("⚠️ [ThankYou] Dashboard data fetch completed but no data - retrying...")
                    // Retry once
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MeterDataManager.shared.fetchMeterData(force: true)

                    // Try audio download again after retry
                    if let audioUrls = MeterDataManager.shared.todaysHack?.audioUrls, !audioUrls.isEmpty {
                        await AudioCacheManager.shared.preDownloadAudioFiles(audioUrls)
                    }

                    await MainActor.run {
                        isDashboardReady = true
                    }
                }
            }
        }
    }

    private func startLoadingAnimation() {
        // Message 1: "Setting up your profile..." (0-33%)
        currentMessage = messages[0]

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if progress < 33 {
                progress += 1
                
                // Milestone haptics - every 20%
                if Int(progress) % 20 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else if progress < 34 {
                // Switch to message 2 - special haptic combo
                currentMessage = messages[1]
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                progress += 1
            } else if progress < 66 {
                progress += 1
                
                // Milestone haptics - every 20%
                if Int(progress) % 20 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else if progress < 67 {
                // Switch to message 3 - special haptic combo
                currentMessage = messages[2]
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                progress += 1
            } else if progress < 90 {
                progress += 1
                
                // Milestone haptics - every 20%
                if Int(progress) % 20 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else if progress < 91 {
                // Switch to final message while waiting for dashboard - special haptic combo
                currentMessage = messages[3]
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                progress += 1
            } else if progress < 95 {
                // Slow down near the end while waiting for data
                progress += 0.3
            } else if progress < 99 {
                // Approaching 99% - slow crawl
                progress += 0.1
            } else if progress >= 99 && progress < 99.5 && !isDashboardReady {
                // ✅ At 99% - show "Almost there..." and start pulsing
                currentMessage = messages[4]  // "Almost there..."
                isPulsing = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                progress = 99  // Lock at 99%
            } else if isDashboardReady && progress < 100 {
                // Dashboard is ready - finish quickly
                isPulsing = false  // Stop pulsing
                progress += 2
            } else if progress >= 100 {
                // Reached 100% AND dashboard is ready
                timer.invalidate()
                
                // 100% completion - TRIPLE CELEBRATION!
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                
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


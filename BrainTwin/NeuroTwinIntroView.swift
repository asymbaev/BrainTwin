import SwiftUI
import AVKit
import Combine

// MARK: - Single Screen Intro with Phone Mockup & Video
struct NeuroTwinIntroView: View {
    var onGetStarted: () -> Void = {}
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var phoneAppeared = false
    @State private var textAppeared = false
    @State private var buttonAppeared = false
    
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            // Use app's background color
            Color.appBackground.ignoresSafeArea()
            
            // Subtle gradient overlay for depth
                RadialGradient(
                    colors: [
                    Color.appAccent.opacity(0.03),
                    Color.clear
                    ],
                center: .top,
                    startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)
                
                // Phone mockup
                PhoneMockupView()
                    .frame(height: 380)
                    .scaleEffect(phoneAppeared ? 1.0 : 0.85)
                    .opacity(phoneAppeared ? 1.0 : 0)
                
                Spacer()
                    .frame(height: 95)
                
                // Headline
                VStack(spacing: 4) {
                    Text("You've been brainwashed.")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(0.2)
                        .foregroundColor(.appTextPrimary)
                    
                    Text("Time to reverse it.")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(0.2)
                        .foregroundColor(.appTextPrimary)
                }
                .opacity(textAppeared ? 1.0 : 0)
                .offset(y: textAppeared ? 0 : 20)
                
                Spacer()
                    .frame(minHeight: 40)
                
                // Get Started Button & Terms
                VStack(spacing: 16) {
                    Button(action: onGetStarted) {
                        Text("Get started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.appAccent)
                            .cornerRadius(16)
                            .shadow(color: Color.appAccent.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 28)
                    
                    // Terms text
                    VStack(spacing: 2) {
                        Text("By continuing, you agree to our")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextTertiary)
                        
                        HStack(spacing: 4) {
                            Button(action: { /* Open terms */ }) {
                                Text("Terms of Service")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                            }
                            
                            Text("and")
                                .font(.system(size: 11))
                                .foregroundColor(.appTextTertiary)
                            
                            Button(action: { /* Open privacy */ }) {
                                Text("Privacy Policy")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                            }
                        }
                    }
                }
                .opacity(buttonAppeared ? 1.0 : 0)
                .offset(y: buttonAppeared ? 0 : 20)
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            // Staggered entrance animations
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75, blendDuration: 0)) {
                phoneAppeared = true
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textAppeared = true
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                buttonAppeared = true
            }
        }
    }
}

// MARK: - Scale Button Style for tactile feedback
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Phone Mockup with Video Player (iPhone 15 Pro Style)
struct PhoneMockupView: View {
    @StateObject private var videoManager = VideoPlayerManager()
    
    var body: some View {
        ZStack {
            // Soft colored background glow behind phone
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.85, blue: 0.7).opacity(0.4),
                            Color(red: 1.0, green: 0.9, blue: 0.8).opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
            
            // iPhone 15 Pro frame - very thin bezel, sleek modern look
            RoundedRectangle(cornerRadius: 42)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.2),
                            Color(white: 0.14),
                            Color(white: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 195, height: 410)
                .overlay(
                    // Subtle inner highlight
                    RoundedRectangle(cornerRadius: 42)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    // Outer edge - thin
                    RoundedRectangle(cornerRadius: 42)
                        .strokeBorder(Color.black.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            
            // Side buttons - very thin and subtle
            // Volume buttons
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(white: 0.18))
                .frame(width: 2, height: 26)
                .offset(x: -99, y: -36)
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(white: 0.18))
                .frame(width: 2, height: 26)
                .offset(x: -99, y: 2)
            
            // Power button
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(white: 0.18))
                .frame(width: 2, height: 48)
                .offset(x: 99, y: -10)
            
            // Screen content with video - larger to show thin bezel
            if videoManager.player != nil {
                LoopingVideoPlayerView(player: videoManager.player!)
                    .frame(width: 182, height: 396)
                    .clipShape(RoundedRectangle(cornerRadius: 38))
            } else {
                // Loading state
                ZStack {
                    Color.black
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(width: 182, height: 396)
                .clipShape(RoundedRectangle(cornerRadius: 38))
            }
            
            // Dynamic Island - smaller
            Capsule()
                .fill(Color.black)
                .frame(width: 90, height: 28)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .offset(y: -183)
        }
    }
}

// MARK: - Video Player Manager
class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    private var looper: AVPlayerLooper?
    
    init() {
        setupPlayer()
    }
    
    private func setupPlayer() {
        // Load the video file
        guard let url = Bundle.main.url(forResource: "intro_video", withExtension: "mp4") else {
            print("❌ Video file 'intro_video.mp4' not found in bundle")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            
            // List all files in bundle for debugging
            if let resourcePath = Bundle.main.resourcePath {
                let files = try? FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("📂 Files in bundle: \(files?.prefix(10) ?? [])")
            }
            return
        }
        
        print("✅ Found video: intro_video.mp4")
        print("📹 Video URL: \(url)")
        
        // Create player item and queue player for seamless looping
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        
        // Setup looper for seamless repeat
        looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        queuePlayer.isMuted = true
        
        // Ensure player is ready before playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            queuePlayer.play()
        }
        
        self.player = queuePlayer
    }
}

// MARK: - Looping Video Player View (without controls)
struct LoopingVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
    
    // Custom UIView with AVPlayerLayer
    class PlayerView: UIView {
        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }
        
        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }
    }
}

// MARK: - Preview
#Preview {
    NeuroTwinIntroView(onGetStarted: {
        print("Get Started tapped")
    })
    .preferredColorScheme(.light)
}

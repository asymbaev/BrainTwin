import SwiftUI

struct NeuralNetworkAnimationView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    var onComplete: () -> Void
    
    // Typewriter state
    @State private var appNameVisibleCount = 0
    @State private var taglineVisibleCount = 0
    
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
    
    // MARK: - Copy
    
    private let appName = "NeuroTwin"
    private let taglineLines = [
        "Your mind.",
        "Rewired.",
        "Starting today."
    ]
    
    private var totalTaglineCharacters: Int {
        taglineLines.reduce(0) { $0 + $1.count }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.10, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Soft static glow behind the title
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.appAccent.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 420
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 60)
                .allowsHitTesting(false)
            
            // Centered content
            VStack(spacing: 20) {
                
                // App name – premium typewriter per character
                HStack(spacing: 2) {
                    let chars = Array(appName)
                    ForEach(chars.indices, id: \.self) { index in
                        let char = String(chars[index])
                        let isVisible = index < appNameVisibleCount
                        
                        Text(char)
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(isVisible ? 1 : 0)
                            .blur(radius: isVisible ? 0 : 1.5)
                            .scaleEffect(isVisible ? 1.0 : 0.98) // tiny, classy scale-in
                            .shadow(
                                color: Color.appAccent.opacity(isVisible ? 0.6 : 0),
                                radius: 14,
                                y: 0
                            )
                            .animation(
                                .easeOut(duration: 0.22), // smoother fade
                                value: isVisible
                            )
                    }
                }
                
                // Tagline – typewriter per character, same premium feel
                VStack(spacing: 4) {
                    ForEach(taglineLines.indices, id: \.self) { lineIndex in
                        HStack(spacing: 0) {
                            let line = taglineLines[lineIndex]
                            let chars = Array(line)
                            
                            ForEach(chars.indices, id: \.self) { charIndex in
                                let ch = chars[charIndex]
                                let globalIndex = taglineGlobalCharIndex(
                                    line: lineIndex,
                                    charIndex: charIndex
                                )
                                
                                let isVisible = (ch == " ") || (globalIndex < taglineVisibleCount)
                                
                                Text(String(ch))
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                    .opacity(isVisible ? 1 : 0)
                                    .blur(radius: isVisible ? 0 : 1.3)
                                    .scaleEffect(isVisible ? 1.0 : 0.985)
                                    .animation(
                                        .easeOut(duration: 0.22),
                                        value: isVisible
                                    )
                            }
                        }
                    }
                }
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            startTypewriter()
        }
    }
    
    // MARK: - Typewriter Logic
    
    private func startTypewriter() {
        let appChars = appName.count
        let taglineChars = totalTaglineCharacters
        
        // Slightly slower letters + overlapping fade
        let charInterval = 0.10          // time between *starting* each char
        let holdAtEnd: Double = 1.2      // how long to sit on full screen
        
        // 1) Reveal app name characters
        for i in 0..<appChars {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * charInterval) {
                appNameVisibleCount = i + 1
            }
        }
        
        // 2) Then reveal tagline characters (with a short pause)
        let taglineStartDelay = Double(appChars) * charInterval + 0.35
        
        for i in 0..<taglineChars {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + taglineStartDelay + Double(i) * charInterval
            ) {
                taglineVisibleCount = i + 1
            }
        }
        
        // 3) Call onComplete after everything is done + hold
        let totalDuration =
            taglineStartDelay + Double(taglineChars) * charInterval + holdAtEnd
        
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            onComplete()
        }
    }
    
    // Flatten (line, charIndex) into a single sequence index for tagline
    private func taglineGlobalCharIndex(line: Int, charIndex: Int) -> Int {
        var index = 0
        for l in 0..<line {
            index += taglineLines[l].count
        }
        return index + charIndex
    }
}

#Preview {
    NeuralNetworkAnimationView { }
}

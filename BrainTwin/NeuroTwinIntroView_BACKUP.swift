import SwiftUI
import Combine

// MARK: - Launch / Intro screen with Adaptive Neural Network Animation
// BACKUP VERSION - Original NeuroTwin branding intro
struct NeuroTwinIntroView_BACKUP: View {
    var onGetStarted: () -> Void = {}
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
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
            
            // ✅ NEW: Floating Neural Network Animation
            NeuralNetworkAnimation_BACKUP()
            
            VStack(spacing: 20) {
                Spacer(minLength: 80)

                Text("NeuroTwin")
                    .font(ntSatoshi(44, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(Color.appTextPrimary)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .clear, radius: 8, y: 4)

                Text("Rewire your mind to the level of your goals.")
                    .font(ntSatoshi(18, weight: .medium))
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Spacer()

                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(ntSatoshi(17, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.appAccent)
                        .cornerRadius(16)
                        .padding(.horizontal, 28)
                }
                .buttonStyle(.plain)

                Text("Backed by neuroscience")
                    .font(ntSatoshi(12, weight: .regular))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.top, 14)
                    .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    // Satoshi font helper (falls back to system if missing)
    private func ntSatoshi(_ size: CGFloat, weight: NTWeight) -> Font {
        let name: String
        switch weight {
        case .regular:  name = "Satoshi-Regular"
        case .medium:   name = "Satoshi-Medium"
        case .semibold: name = "Satoshi-SemiBold"
        case .bold:     name = "Satoshi-Bold"
        }
        return Font.custom(name, size: size, relativeTo: .body).weight(weight.swiftWeight)
    }

    private enum NTWeight {
        case regular, medium, semibold, bold
        var swiftWeight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }
}

// MARK: - Neural Network Animation (BULLETPROOF VERSION)
struct NeuralNetworkAnimation_BACKUP: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var particles: [Neuron_BACKUP] = []
    @State private var screenSize: CGSize = .zero
    
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Just READ and DRAW - no state modification
                
                // Draw connections
                let connectionDistance: CGFloat = 120
                for i in 0..<particles.count {
                    for j in (i+1)..<particles.count {
                        let dx = particles[i].x - particles[j].x
                        let dy = particles[i].y - particles[j].y
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        if distance < connectionDistance {
                            let opacity = 1 - (distance / connectionDistance)
                            var path = Path()
                            path.move(to: CGPoint(x: particles[i].x, y: particles[i].y))
                            path.addLine(to: CGPoint(x: particles[j].x, y: particles[j].y))
                            
                            let connectionColor = colorScheme == .dark
                                ? Color.appAccent.opacity(opacity * 0.3)
                                : Color.appTextPrimary.opacity(opacity * 0.2)
                            
                            context.stroke(path, with: .color(connectionColor), lineWidth: 1.5)
                        }
                    }
                }
                
                // Draw particles
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x - particle.size / 2,
                        y: particle.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    let particleColor = colorScheme == .dark
                        ? Color.white.opacity(particle.opacity)
                        : Color.appTextPrimary.opacity(particle.opacity * 0.7)
                    
                    context.fill(Path(ellipseIn: rect), with: .color(particleColor))
                    
                    // Glow in dark mode
                    if colorScheme == .dark {
                        let glowRect = rect.insetBy(dx: -2, dy: -2)
                        context.fill(
                            Path(ellipseIn: glowRect),
                            with: .color(Color.appAccent.opacity(particle.opacity * 0.2))
                        )
                    }
                }
            }
            .onAppear {
                screenSize = geometry.size
                // Initialize particles
                particles = (0..<60).map { _ in
                    Neuron_BACKUP(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height),
                        vx: CGFloat.random(in: -0.5...0.5),
                        vy: CGFloat.random(in: -0.5...0.5),
                        size: CGFloat.random(in: 4...7),
                        opacity: Double.random(in: 0.6...1.0)
                    )
                }
            }
            .onReceive(timer) { _ in
                // Update particles on timer (separate from rendering)
                for i in particles.indices {
                    particles[i].update(size: screenSize, time: Date().timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Neuron Particle Model
struct Neuron_BACKUP {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    let size: CGFloat
    let opacity: Double
    
    mutating func update(size: CGSize, time: TimeInterval) {
        let wave = sin(time * 0.5 + x * 0.01) * 0.3
        
        x += vx + wave
        y += vy
        
        // Wrap around edges
        if x < -10 { x = size.width + 10 }
        if x > size.width + 10 { x = -10 }
        if y < -10 { y = size.height + 10 }
        if y > size.height + 10 { y = -10 }
    }
}


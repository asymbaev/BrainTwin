import SwiftUI

// MARK: - Voice Selector Card Carousel
struct VoiceSelectorView: View {
    @Binding var selectedVoiceIndex: Int
    @Binding var isPresented: Bool
    let voices: [(name: String, voiceId: String)]
    let onVoiceSelected: (Int) -> Void
    
    @State private var currentCardIndex = 0
    @State private var isAnimatingWaveform = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background with blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Voice Selector Container
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Select Voice")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.appTextTertiary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    Text("Swipe to preview different voices")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal, 24)
                    
                    // Card Carousel
                    TabView(selection: $currentCardIndex) {
                        ForEach(0..<voices.count, id: \.self) { index in
                            VoiceCard(
                                voice: voices[index],
                                isSelected: selectedVoiceIndex == index,
                                index: index
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 320)
                    .onChange(of: currentCardIndex) { _, newIndex in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    
                    // Page Indicator Dots
                    HStack(spacing: 8) {
                        ForEach(0..<voices.count, id: \.self) { index in
                            Circle()
                                .fill(currentCardIndex == index ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing))
                                .frame(width: currentCardIndex == index ? 8 : 6, height: currentCardIndex == index ? 8 : 6)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentCardIndex)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Select Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onVoiceSelected(currentCardIndex)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedVoiceIndex == currentCardIndex ? "checkmark.circle.fill" : "waveform")
                                .font(.headline)
                            
                            Text(selectedVoiceIndex == currentCardIndex ? "Currently Selected" : "Select This Voice")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            selectedVoiceIndex == currentCardIndex ?
                                LinearGradient(colors: [Color.appTextSecondary], startPoint: .leading, endPoint: .trailing) :
                                Color.appAccentGradient
                        )
                        .cornerRadius(16)
                        .shadow(
                            color: selectedVoiceIndex == currentCardIndex ? .clear : Color.appAccent.opacity(0.3),
                            radius: 12
                        )
                    }
                    .disabled(selectedVoiceIndex == currentCardIndex)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.appBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.appCardBorder.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            currentCardIndex = selectedVoiceIndex
        }
    }
}

// MARK: - Voice Card Component
struct VoiceCard: View {
    let voice: (name: String, voiceId: String)
    let isSelected: Bool
    let index: Int
    
    @State private var isAnimating = false
    
    // Parse voice characteristics from name
    private var voiceName: String {
        voice.name.components(separatedBy: " (").first ?? voice.name
    }
    
    private var characteristics: [String] {
        guard let characterPart = voice.name.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "") else {
            return []
        }
        return characterPart.components(separatedBy: ", ")
    }
    
    private var voiceIcon: String {
        characteristics.contains("Male") ? "🎙️" : "🎶"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon with animated glow
            ZStack {
                // Glow effect for selected voice
                if isSelected {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.appAccent.opacity(0.3),
                                    Color.orange.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .opacity(isAnimating ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isSelected ? [
                                Color.appAccent.opacity(0.2),
                                Color.orange.opacity(0.2)
                            ] : [
                                Color.appCardBackground,
                                Color.appCardBackground
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
                
                // Voice icon
                Text(voiceIcon)
                    .font(.system(size: 48))
                
                // Animated waveform overlay
                if isAnimating {
                    AnimatedWaveformView()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }
            }
            .onAppear {
                if isSelected {
                    isAnimating = true
                }
            }
            .onChange(of: isSelected) { _, newValue in
                isAnimating = newValue
            }
            
            // Voice Name
            Text(voiceName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.appTextPrimary)
            
            // Characteristics Chips
            HStack(spacing: 8) {
                ForEach(characteristics, id: \.self) { characteristic in
                    Text(characteristic)
                        .font(.caption.bold())
                        .foregroundColor(isSelected ? .white : .appTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ?
                                Color.appAccentGradient :
                                LinearGradient(colors: [Color.appCardBackground], startPoint: .leading, endPoint: .trailing)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appCardBorder, lineWidth: isSelected ? 0 : 1)
                        )
                        .cornerRadius(12)
                }
            }
            
            // Selected indicator
            if isSelected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                    Text("Currently Active")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.appAccent)
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            isSelected ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected ? Color.appAccent.opacity(0.3) : .clear,
                    radius: isSelected ? 16 : 0,
                    y: isSelected ? 8 : 0
                )
        )
        .padding(.horizontal, 20)
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Animated Waveform View
struct AnimatedWaveformView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Canvas { context, size in
            let path = Path { p in
                let width = size.width
                let height = size.height
                let midY = height / 2
                
                p.move(to: CGPoint(x: 0, y: midY))
                
                for x in stride(from: 0, through: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin((relativeX + phase) * .pi * 4)
                    let y = midY + sine * 15
                    p.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [Color.appAccent.opacity(0.6), Color.orange.opacity(0.6)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                lineWidth: 2
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

#Preview {
    VoiceSelectorView(
        selectedVoiceIndex: .constant(0),
        isPresented: .constant(true),
        voices: [
            ("Onyx (Male, Powerful)", "onyx"),
            ("Echo (Male, Deep)", "echo"),
            ("Shimmer (Female, Calm)", "shimmer"),
            ("Nova (Female, Warm)", "nova")
        ],
        onVoiceSelected: { _ in }
    )
}

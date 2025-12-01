import SwiftUI

struct HackIntroView: View {
    @StateObject private var viewModel = DailyHackViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var hackMode: HackMode?
    
    enum HackMode: Identifiable {
        case read, listen
        
        var id: String {
            switch self {
            case .read: return "read"
            case .listen: return "listen"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Show loading card immediately
            VStack(spacing: 20) {
                // Top bar with title and close
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("YOUR BRAIN HACK")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("• 1 MIN")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title3)
                            .padding(10)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                if let hack = viewModel.todaysHack {
                    // Hack loaded - show actual content
                    Text(hack.hackName)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                    
                    // Tags
                    HStack(spacing: 12) {
                        tagView(text: "FOCUS")
                        tagView(text: "DISCIPLINE")
                        tagView(text: "MOTIVATION")
                    }
                    .transition(.opacity)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Listen button
                        Button {
                            guard viewModel.todaysHack != nil else { return }
                            print("🎧 Opening Listen mode")
                            hackMode = .listen
                        } label: {
                            HStack {
                                Image(systemName: "headphones")
                                Text("Listen")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                        
                        // Read button
                        Button {
                            guard viewModel.todaysHack != nil else { return }
                            print("📖 Opening Read mode")
                            hackMode = .read
                        } label: {
                            HStack {
                                Image(systemName: "book")
                                Text("Read")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                    .transition(.opacity)
                    
                } else if viewModel.errorMessage != nil {
                    // Error
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text("Failed to load hack")
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 60)
                    
                } else {
                    // Loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.appAccent)

                        Text("Generating your brain hack...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Powered by neuroscience")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 60)
                }
            }
            .background(
                ZStack {
                    // Background image
                    AsyncImage(url: URL(string: ImageService.getTodaysImage())) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    
                    // Dark overlay
                    Color.black.opacity(0.5)
                }
            )
            .cornerRadius(20)
            .padding()
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.clear)
        .task {
            await viewModel.loadTodaysHack()
        }
        .fullScreenCover(item: $hackMode) { mode in
            let autoPlay = (mode == .listen)
            DailyHackView(
                autoPlayVoice: autoPlay,
                preloadedHack: viewModel.todaysHack,
                preGeneratedAudioUrls: viewModel.todaysHack?.audioUrls ?? []
            )
        }
    }
    
    private func tagView(text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    ZStack {
        Color.purple.ignoresSafeArea()
        HackIntroView()
    }
}

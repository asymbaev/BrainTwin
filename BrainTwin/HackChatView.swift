import SwiftUI

enum HackPage {
    case quote
    case science
    case application
}

struct HackChatView: View {
    let hack: BrainHack
    let fromPage: HackPage
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // ✅ ADD THIS: Appearance override (same as DailyHackView)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    // ✅ ADD THIS: Computed color scheme based on user preference
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System
        }
    }
    
    var suggestedPrompts: [String] {
        switch fromPage {
        case .quote:
            return [
                "What does this hack mean exactly?",
                "How is this different from other techniques?",
                "Can you explain this in simpler terms?",
                "Why is this particular hack effective?",
                "What's a real-world example of this?"
            ]
        case .science:
            return [
                "Can you explain the brain science more?",
                "What brain regions are involved?",
                "How long does it take to rewire?",
                "What research supports this?",
                "Why does this work neurologically?"
            ]
        case .application:
            return [
                "How can I apply this today?",
                "What if I forget to use it?",
                "Can I combine this with other habits?",
                "How do I track my progress?",
                "What are common mistakes to avoid?"
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation (only Back) - ADAPTIVE
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(colorScheme == .dark ? .white : .appTextPrimary)
                        .padding(8)
                }

                Spacer()
            }
            .padding()
            .background(Color.appCardBackground.opacity(0.5))

            ScrollView {
                VStack(spacing: 20) {
                    // Add spacer to center content
                    Spacer()
                        .frame(height: 60)
                    
                    // NeuroChat-style icon (only when no messages)
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 16) {
                            // Gradient icon (matching main ChatView)
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appAccent, Color.orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                    .blur(radius: 15)
                                    .opacity(0.6)
                                
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appAccent, Color.orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: "message.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Chat with NeuroChat")
                                .font(.title2.bold())
                                .foregroundColor(.appTextPrimary)
                            
                            Text("Ask me anything about this hack")
                                .font(.subheadline)
                                .foregroundColor(.appTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 20)
                    }
                    
                    // Suggested Prompts - pill chips
                    if viewModel.messages.isEmpty {
                        suggestedPromptsView
                            .padding(.bottom, 20)
                    }
                    
                    // Chat Messages
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, isAnimated: true)
                            .padding(.horizontal)
                    }
                    
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .tint(.appAccent)
                            Text("Thinking...")
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding()
                    }
                    
                    Color.clear.frame(height: 20)
                }
            }
            
            // Bottom Input
            chatInputView
        }
        .background(
            ZStack {
                // Adaptive background (same as dashboard)
                Color.appBackground.ignoresSafeArea()
                
                // Subtle depth gradient (only in dark mode)
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
            }
        )
        // ✅ ADD THIS: Apply user's preferred color scheme (just like DailyHackView)
        .preferredColorScheme(preferredColorScheme)
        .navigationBarHidden(true)
    }
    
    // MARK: - Suggested Prompts - ADAPTIVE
    
    private var suggestedPromptsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestedPrompts, id: \.self) { prompt in
                        Button {
                            sendPrompt(prompt)
                        } label: {
                            HStack {
                                Text(prompt)
                                    .font(.subheadline)
                                    .foregroundColor(.appTextPrimary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                            }
                            .padding()
                            .frame(width: 280)
                            .background(Color.appCardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appCardBorder, lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Chat Input - ADAPTIVE
    
    private var chatInputView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.appCardBorder)

            HStack(spacing: 12) {
                // TextField with custom placeholder
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "text.cursor")
                                .font(.subheadline)
                                .foregroundColor(.appTextSecondary)
                            Text("Write any question here")
                                .foregroundColor(.appTextSecondary)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                    }

                    TextField("", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .focused($isTextFieldFocused)
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }
                }
                .background(Color.appCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appCardBorder, lineWidth: 1)
                )
                .cornerRadius(12)

                // Send Button - ADAPTIVE
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(messageText.isEmpty ? .appTextSecondary : (colorScheme == .dark ? .black : .white))
                        .frame(width: 44, height: 44)
                        .background(messageText.isEmpty ? Color.appCardBackground : Color.appAccent)
                        .overlay(
                            Circle()
                                .stroke(Color.appCardBorder, lineWidth: messageText.isEmpty ? 1 : 0)
                        )
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty)
                .animation(.easeInOut(duration: 0.15), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appBackground)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            await viewModel.sendMessage(text)
        }
    }
    
    private func sendPrompt(_ prompt: String) {
        Task {
            await viewModel.sendMessage(prompt)
        }
    }
}

#Preview {
    HackChatView(
        hack: BrainHack(
            hackName: "Dopamine Priming",
            quote: "Start small to build momentum",
            explanation: "Begin with a 2-minute task...",
            neuroscience: "This activates your reward circuits...",
            personalization: "For your goal...",
            barrier: "procrastination",
            isCompleted: false,
            audioUrls: nil
        ),
        fromPage: .quote
    )
}

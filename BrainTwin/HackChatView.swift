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
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
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
            // Top Navigation (only Back)
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8) // a bit larger tap target
                }

                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.35)) // lighter tint (optional)

            ScrollView {
                VStack(spacing: 20) {
                    // Add spacer to center content in lower area
                    Spacer()
                        .frame(height: 120)
                    
                    // Animated Brain Logo (only when no messages)
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.9))
                                .symbolEffect(.pulse, options: .repeating)  // Continuous animation
                            
                            Text("Ask me anything about this hack")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 30)
                    }
                    
                    // Suggested Prompts - Now very close to bottom
                    if viewModel.messages.isEmpty {
                        suggestedPromptsView
                            .padding(.bottom, 20)
                    }
                    
                    // Chat Messages
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .padding(.horizontal)
                    }
                    
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Thinking...")
                                .foregroundColor(.white.opacity(0.7))
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
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.85, blue: 0.35),  // Warm gold/yellow
                    Color(red: 0.55, green: 0.45, blue: 0.75),  // Mid purple
                    Color(red: 0.25, green: 0.15, blue: 0.45)   // Deep purple (dashboard color)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
    }
    
    // MARK: - Suggested Prompts
    
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
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                            .frame(width: 280)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Chat Input
    
    private var chatInputView: some View {
        VStack(spacing: 0) {
            Divider().background(.white.opacity(0.2))

            HStack(spacing: 12) {
                // TextField with custom placeholder (icon optional—kept subtle)
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "text.cursor")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Write any question here")
                                .foregroundColor(.white.opacity(0.75))
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                    }

                    TextField("", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .focused($isTextFieldFocused)
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }
                }
                .background(.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
                .cornerRadius(12)

                // Send
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(messageText.isEmpty ? .white.opacity(0.12) : .blue)
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty)
                .opacity(messageText.isEmpty ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial) // lighter than the dark purple
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

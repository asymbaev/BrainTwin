import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    var initialContext: String? = nil
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var animatedMessages: Set<UUID> = []

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            // Clean background
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages / Welcome
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if viewModel.messages.isEmpty {
                                welcomeView
                            }

                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, isAnimated: animatedMessages.contains(message.id))
                                    .id(message.id)
                                    .onAppear {
                                        if !animatedMessages.contains(message.id) {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                animatedMessages.insert(message.id)
                                            }
                                        }
                                    }
                            }

                            if viewModel.isLoading {
                                typingIndicator
                            }

                            Color.clear.frame(height: 16)
                                .id("bottom")
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isTextFieldFocused = false
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { value in
                            if value.translation.height > 10 {
                                isTextFieldFocused = false
                            }
                        }
                    )
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                // Suggested Prompts (only when empty)
                if viewModel.messages.isEmpty && !viewModel.isLoading {
                    suggestedPromptsView
                }

                // Glassmorphism Input Bar
                inputBar
            }
        }
        .navigationTitle("NeuroChat")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            // Removed auto-focus - keyboard only appears when user taps input
            if let context = initialContext {
                Task { await viewModel.sendMessage(context) }
            }
        }
    }

    // MARK: - Suggested Prompts
    
    private var suggestedPromptsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button {
                        messageText = prompt
                        sendMessage()
                    } label: {
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundColor(.appTextPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.appCardBackground)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.appAccent.opacity(0.3), Color.orange.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    
    private var suggestedPrompts: [String] {
        [
            "Help me build better habits",
            "Why do I procrastinate?",
            "Tips for staying motivated",
            "Improve my focus"
        ]
    }

    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 16) {
            // Gradient icon
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
            .padding(.top, 40)
            
            Text("Chat with NeuroChat")
                .font(.title2.bold())
                .foregroundColor(.appTextPrimary)

            Text("Ask me anything about your habits, challenges, or personal growth.")
                .font(.subheadline)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Typing Indicator
    
    private var typingIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent, Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 8, height: 8)
                    .offset(y: typingOffset(for: index))
            }
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    private func typingOffset(for index: Int) -> CGFloat {
        let animation = Animation
            .easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
            .delay(Double(index) * 0.2)
        
        return withAnimation(animation) {
            viewModel.isLoading ? -4 : 0
        } ?? 0
    }

    // MARK: - Input Bar with Glassmorphism
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Glassmorphism container
            HStack(spacing: 12) {
                // Text Input Field
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "text.cursor")
                                .font(.subheadline)
                                .foregroundColor(.appTextSecondary)
                            Text("Message NeuroChat...")
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
                        .lineLimit(1...4)
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }
                }
                .background(Color.appCardBackground.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isTextFieldFocused ?
                            LinearGradient(
                                colors: [Color.appAccent, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.appCardBorder, Color.appCardBorder],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: isTextFieldFocused ? 2 : 1
                        )
                )
                .cornerRadius(20)

                // Send Button with Animation
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "arrow.up.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(
                                    messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                    LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [Color.appAccent, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 44, height: 44)
                        )
                        .scaleEffect(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 1.1)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: messageText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16) // Increased for more premium feel
            .background(
                Color.appBackground
                    .opacity(0.95)
                    .blur(radius: 10)
            )
        }
        .background(Color.appBackground)
    }

    // MARK: - Actions
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        messageText = ""
        isTextFieldFocused = false
        Task { await viewModel.sendMessage(text) }
    }
}

// MARK: - Message Bubble with Gradient & Animation

struct MessageBubble: View {
    let message: ChatMessage
    let isAnimated: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isUser { Spacer(minLength: 40) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(message.isUser ? .white : .appTextPrimary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if message.isUser {
                                // Gradient bubble for user
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appAccent, Color.orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                            } else {
                                // Solid bubble for AI
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.appCardBackground)
                            }
                        }
                    )

                Text(message.timestamp, style: .time)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary.opacity(0.7))
                    .padding(.horizontal, 4)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            .opacity(isAnimated ? 1.0 : 0)

            if !message.isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Model

struct ChatMessage: Identifiable {
    let id = UUID()
    var text: String // Changed to var for typing animation
    let isUser: Bool
    let timestamp: Date
}

// MARK: - Preview

#Preview {
    NavigationStack { ChatView() }
}

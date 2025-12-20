import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    var initialContext: String? = nil
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Welcome
                        if viewModel.messages.isEmpty && !viewModel.isLoading {
                            welcomeView
                        }

                        // Messages
                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }

                        // Typing
                        if viewModel.isLoading {
                            typingIndicator
                        }

                        Color.clear.frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .background(Color.appBackground)
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Input
            inputBar
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("NeuroChat")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            if let context = initialContext {
                Task { await viewModel.sendMessage(context) }
            }
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("NeuroChat")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.appTextPrimary)

                Text("Ask anything about your habits, challenges, or personal growth.")
                    .font(.body)
                    .foregroundColor(.appTextSecondary)
                    .lineSpacing(6)
            }

            // Suggested
            VStack(alignment: .leading, spacing: 12) {
                ForEach([
                    "Help me build better habits",
                    "Why do I procrastinate?",
                    "How to stay motivated",
                    "Improve my focus"
                ], id: \.self) { prompt in
                    Button {
                        messageText = prompt
                        sendMessage()
                    } label: {
                        HStack(spacing: 8) {
                            Text("→")
                                .foregroundColor(.appTextSecondary)
                            Text(prompt)
                                .foregroundColor(.appTextPrimary)
                        }
                        .font(.body)
                    }
                }
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Message Row

    private func messageRow(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if message.isUser {
                // User message
                VStack(alignment: .leading, spacing: 6) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.appTextPrimary)
                        .lineSpacing(6)

                    Text(message.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.appTextSecondary.opacity(0.6))
                }
            } else {
                // AI response
                VStack(alignment: .leading, spacing: 16) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.appTextPrimary)
                        .lineSpacing(8)

                    // Actions
                    HStack(spacing: 24) {
                        actionButton(icon: "→", label: "Try this") {
                            // Action
                        }

                        actionButton(icon: "⌘", label: "Copy") {
                            UIPasteboard.general.string = message.text
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                    }
                    .font(.subheadline)
                }
            }

            // Divider
            Rectangle()
                .fill(Color.appTextSecondary.opacity(0.1))
                .frame(height: 1)
                .padding(.top, 8)
        }
        .padding(.bottom, 24)
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(icon)
                    .foregroundColor(.appTextSecondary)
                Text(label)
                    .foregroundColor(.appTextSecondary)
            }
        }
    }

    // MARK: - Typing

    private var typingIndicator: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.appTextSecondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .offset(y: typingOffset(for: index))
                }
            }

            Rectangle()
                .fill(Color.appTextSecondary.opacity(0.1))
                .frame(height: 1)
                .padding(.top, 8)
        }
        .padding(.bottom, 24)
    }

    private func typingOffset(for index: Int) -> CGFloat {
        let animation = Animation
            .easeInOut(duration: 0.5)
            .repeatForever(autoreverses: true)
            .delay(Double(index) * 0.12)

        return withAnimation(animation) {
            viewModel.isLoading ? -3 : 0
        } ?? 0
    }

    // MARK: - Input

    private var inputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.appTextSecondary.opacity(0.1))
                .frame(height: 1)

            HStack(spacing: 0) {
                TextField("", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundColor(.appTextPrimary)
                    .placeholder(when: messageText.isEmpty) {
                        Text("Type a message...")
                            .foregroundColor(.appTextSecondary.opacity(0.4))
                    }
                    .focused($isTextFieldFocused)
                    .lineLimit(1...8)
                    .submitLabel(.send)
                    .onSubmit { sendMessage() }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .accentColor(.appAccent)

                if !messageText.isEmpty {
                    Button {
                        sendMessage()
                    } label: {
                        Text("→")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.appAccent)
                            .padding(.trailing, 24)
                    }
                    .transition(.opacity)
                }
            }
            .background(Color.appBackground)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        messageText = ""
        Task { await viewModel.sendMessage(text) }
    }
}

// MARK: - Model

struct ChatMessage: Identifiable {
    let id = UUID()
    var text: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - Preview

#Preview {
    NavigationStack { ChatView() }
}

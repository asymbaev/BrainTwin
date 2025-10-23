import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    var initialContext: String? = nil
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Welcome message
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 12) {
                                Text("🧠")
                                    .font(.system(size: 60))

                                Text("Chat with Your Brain Twin")
                                    .font(.title2.bold())

                                Text("I'm here to help you understand your brain and overcome your challenges. Ask me anything!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.top, 40)
                        }

                        // Messages
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message) // new flat style (see below)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack {
                                ProgressView().padding(.leading, 16)
                                Text("Brain Twin is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }

                        // breathing room above input bar
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 90) // keep last message above input bar
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input Area (lighter, with custom placeholder)
            inputBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle("Chat with Brain Twin")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            isTextFieldFocused = true
            if let context = initialContext {
                Task { await viewModel.sendMessage(context) }
            }
        }
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.primary.opacity(0.15))

            HStack(spacing: 12) {
                // Custom placeholder approach gives full control of style
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "text.cursor")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Write any question here")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                    }

                    TextField("", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .focused($isTextFieldFocused)
                        .lineLimit(1...4)
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }
                }
                .background(.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                )
                .cornerRadius(16)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.primary.opacity(0.15) : Color.blue)
                        .clipShape(Circle())
                        .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: messageText)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial) // softer, not dark
        }
    }

    // MARK: - Actions
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messageText = ""
        isTextFieldFocused = false

        Task { await viewModel.sendMessage(text) }
    }
}

// MARK: - Flat Message Bubble (no colored backgrounds)
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 24) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.system(size: 18, weight: .regular, design: .rounded)) // calm, rounded
                    .foregroundColor(.white.opacity(0.96))                        // high contrast
                    .lineSpacing(4)                                              // easier scanning
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1) // subtle halo for gradients
                    .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

                Text(message.timestamp, style: .time)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                    .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: 520, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer(minLength: 24) }
        }
    }
}


// MARK: - Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

#Preview {
    NavigationStack {
        ChatView()
    }
}

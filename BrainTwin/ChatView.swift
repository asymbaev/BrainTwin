import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    // ✅ Appearance override (same as DailyHackView)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    var initialContext: String? = nil
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool

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
            // ✅ Adaptive background (same as DailyHackView pages 2-3)
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
                
                // Keep starfield in dark mode for ambiance
                ChatStarfieldView().ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Messages / Welcome
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 10) {
                                    Text("Chat with Your Brain Twin")
                                        .font(.title2.bold())
                                        .foregroundColor(.appTextPrimary)

                                    Text("I'm here to help you understand your brain and overcome your challenges. Ask me anything!")
                                        .font(.subheadline)
                                        .foregroundColor(.appTextSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .padding(.top, 18)
                            }

                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(.appAccent)
                                        .padding(.leading, 16)
                                    Text("Brain Twin is thinking...")
                                        .font(.caption)
                                        .foregroundColor(.appTextSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }

                            Color.clear.frame(height: 20)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 90)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // Input Area
                inputBar
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.clear)
        // ✅ Apply user's preferred color scheme
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            isTextFieldFocused = true
            if let context = initialContext {
                Task { await viewModel.sendMessage(context) }
            }
        }
    }

    // MARK: - Input Bar - ADAPTIVE
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.appCardBorder)

            HStack(spacing: 12) {
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
                        .lineLimit(1...4)
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }
                }
                .background(Color.appCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appCardBorder, lineWidth: 1)
                )
                .cornerRadius(16)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .appTextSecondary : (colorScheme == .dark ? .black : .white))
                        .frame(width: 44, height: 44)
                        .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.appCardBackground : Color.appAccent)
                        .overlay(
                            Circle()
                                .stroke(Color.appCardBorder, lineWidth: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
                        )
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                .animation(.easeInOut(duration: 0.15), value: messageText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appBackground)
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

// MARK: - Message Bubble - ADAPTIVE
struct MessageBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 24) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

                Text(message.timestamp, style: .time)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
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

// MARK: - Lightweight starfield (only visible in dark mode)
private struct ChatStarfieldView: View {
    @State private var stars: [ChatStar] = []

    var body: some View {
        TimelineView(.animation) { _ in
            GeometryReader { geo in
                Canvas { ctx, size in
                    if stars.isEmpty {
                        stars = (0..<140).map { i in
                            ChatStar(
                                id: i,
                                x: CGFloat.random(in: 0...size.width),
                                y: CGFloat.random(in: 0...size.height),
                                size: CGFloat.random(in: 0.6...2.2),
                                baseOpacity: Double.random(in: 0.25...0.85),
                                blur: CGFloat.random(in: 0...1.4),
                                twinkle: Double.random(in: 1.6...3.4),
                                phase: Double.random(in: 0...(.pi * 2))
                            )
                        }
                    }

                    let t = Date().timeIntervalSinceReferenceDate
                    for s in stars {
                        var starCtx = ctx
                        starCtx.addFilter(.blur(radius: s.blur))
                        let twinkle = 0.35 * (sin(t / s.twinkle + s.phase) + 1) / 2
                        let a = s.baseOpacity * (0.7 + twinkle * 0.6)
                        let rect = CGRect(x: s.x, y: s.y, width: s.size, height: s.size)
                        starCtx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a)))
                    }
                }
            }
        }
    }
}

private struct ChatStar: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let baseOpacity: Double
    let blur: CGFloat
    let twinkle: Double
    let phase: Double
}

// MARK: - Preview
#Preview {
    NavigationStack { ChatView() }
}

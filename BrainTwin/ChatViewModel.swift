import Foundation
import Supabase
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared
    private var typingTask: Task<Void, Never>?
    
    func sendMessage(_ text: String) async {
        guard let userId = supabase.userId else {
            errorMessage = "No user ID found"
            return
        }
        
        // Add user message immediately
        let userMessage = ChatMessage(
            text: text,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("💬 Sending message to Brain Twin...")
            
            // Call chat-with-twin Edge Function
            struct ChatRequest: Encodable {
                let userId: String
                let message: String
            }
            
            struct ChatResponse: Decodable {
                let response: String
                let tokensUsed: Int?
            }
            
            let request = ChatRequest(userId: userId, message: text)
            
            let response: ChatResponse = try await supabase.client.functions.invoke(
                "chat-with-twin",
                options: FunctionInvokeOptions(body: request)
            )
            
            print("✅ Got response from Brain Twin")
            
            isLoading = false
            
            // Add AI response with typing animation
            await typeMessage(response.response, isUser: false)
            
        } catch {
            print("❌ Chat error: \(error)")
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            
            // Add error message to chat
            await typeMessage("Sorry, I couldn't process that. Please try again.", isUser: false)
            
            isLoading = false
        }
    }
    
    // MARK: - Typing Animation
    
    private func typeMessage(_ fullText: String, isUser: Bool) async {
        // Cancel any existing typing animation
        typingTask?.cancel()
        
        // Create placeholder message
        let message = ChatMessage(
            text: "",
            isUser: isUser,
            timestamp: Date()
        )
        
        messages.append(message)
        
        guard let messageIndex = messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }
        
        // Type out character by character
        typingTask = Task {
            for (index, character) in fullText.enumerated() {
                if Task.isCancelled { break }
                
                // Update the message text
                messages[messageIndex].text = String(fullText.prefix(index + 1))
                
                // Typing speed: ~30 characters per second (realistic)
                try? await Task.sleep(nanoseconds: 33_000_000) // 33ms per character
            }
        }
        
        await typingTask?.value
    }
    
    deinit {
        typingTask?.cancel()
    }
}

import Foundation
import Supabase
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared
    
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
            
            // Add Brain Twin response
            let twinMessage = ChatMessage(
                text: response.response,
                isUser: false,
                timestamp: Date()
            )
            messages.append(twinMessage)
            
        } catch {
            print("❌ Chat error: \(error)")
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            
            // Add error message to chat
            let errorMsg = ChatMessage(
                text: "Sorry, I couldn't process that. Please try again.",
                isUser: false,
                timestamp: Date()
            )
            messages.append(errorMsg)
        }
        
        isLoading = false
    }
}

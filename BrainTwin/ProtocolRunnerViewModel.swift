import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
class ProtocolRunnerViewModel: ObservableObject {
    @Published var currentProtocol: Protocol?
    @Published var currentStepIndex = 0
    @Published var timeRemaining = 0
    @Published var isRunning = false
    @Published var isCompleted = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared
    private var timer: Timer?
    
    var currentStep: ProtocolStep? {
        guard let proto = currentProtocol, currentStepIndex < proto.steps.count else {
            return nil
        }
        return proto.steps[currentStepIndex]
    }
    
    var timerProgress: Double {
        guard let step = currentStep, step.durationSeconds > 0 else { return 0 }
        return Double(timeRemaining) / Double(step.durationSeconds)
    }
    
    var canSkip: Bool {
        guard let proto = currentProtocol else { return false }
        return currentStepIndex < proto.steps.count - 1
    }
    
    func loadProtocol() async {
        guard let userId = supabase.userId else {
            errorMessage = "No user ID found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("📋 Generating protocol...")
            
            struct GenerateRequest: Encodable {
                let userId: String
                let forceNew: Bool
            }
            
            struct GenerateResponse: Decodable {
                let protocolData: Protocol
                let message: String
                
                enum CodingKeys: String, CodingKey {
                    case protocolData = "protocol"
                    case message
                }
            }
            
            let request = GenerateRequest(userId: userId, forceNew: false)
            
            let response: GenerateResponse = try await supabase.client.functions.invoke(
                "generate-protocol",
                options: FunctionInvokeOptions(body: request)
            )
            
            print("✅ Protocol loaded: \(response.protocolData.title)")
            
            currentProtocol = response.protocolData
            
            if let firstStep = response.protocolData.steps.first {
                timeRemaining = firstStep.durationSeconds
            }
            
        } catch {
            print("❌ Protocol error: \(error)")
            errorMessage = "Failed to load protocol: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    private func startTimer() {
        isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
            
            if timeRemaining <= 3 && timeRemaining > 0 {
                haptic()
            }
        } else {
            nextStep()
        }
    }
    
    func skipStep() {
        pauseTimer()
        nextStep()
    }
    
    private func nextStep() {
        guard let proto = currentProtocol else { return }
        
        haptic()
        
        if currentStepIndex < proto.steps.count - 1 {
            currentStepIndex += 1
            
            if let step = currentStep {
                timeRemaining = step.durationSeconds
            }
            
            if isRunning {
                startTimer()
            }
        } else {
            completeProtocol()
        }
    }
    
    private func completeProtocol() {
        pauseTimer()
        isCompleted = true
        haptic()
        
        Task {
            await markComplete()
        }
    }
    
    private func markComplete() async {
        guard let proto = currentProtocol else { return }
        
        do {
            print("✅ Marking complete...")
            
            struct UpdateData: Encodable {
                let completed_at: String
            }
            
            let now = ISO8601DateFormatter().string(from: Date())
            let update = UpdateData(completed_at: now)
            
            try await supabase.client
                .from("protocols")
                .update(update)
                .eq("id", value: proto.id)
                .execute()
            
            print("✅ Marked complete")
        } catch {
            print("❌ Mark complete error: \(error)")
        }
    }
    
    private func haptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    deinit {
        timer?.invalidate()
    }
}

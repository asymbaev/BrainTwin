import SwiftUI

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @State private var isLoading = false
    @State private var errorText: String?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if supabase.isSignedIn {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                }
            } else {
                signInView
            }
        }
    }
    
    private var signInView: some View {
        VStack(spacing: 30) {
            Text("🧠")
                .font(.system(size: 80))
            
            Text("Brain Twin")
                .font(.largeTitle.bold())
            
            Text("Your AI neuroscience coach")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                signIn()
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Get Started")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(16)
            .padding(.horizontal, 32)
            .disabled(isLoading)
            
            if let error = errorText {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func signIn() {
        isLoading = true
        errorText = nil
        
        Task {
            do {
                try await supabase.signInAnonymously()
                isLoading = false
            } catch {
                errorText = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
}

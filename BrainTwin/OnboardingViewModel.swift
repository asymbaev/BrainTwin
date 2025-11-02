import Foundation
import Supabase
import Combine
import UserNotifications

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep = 0
    
    // Screen 1: Goal Selection
    @Published var selectedGoal: String = ""  // "Build better habits", "Overcome procrastination", "Reduce anxiety/stress", or "custom"
    @Published var customGoalText: String = ""
    
    // Screen 2: Struggle Selection (UPDATED - Now only 3 + custom)
    @Published var selectedStruggle: String = ""  // "distracted", "falling_back", or "other"
    @Published var customStruggleText: String = ""

    // Screen 3: Time Selection
    @Published var selectedTime: String = ""  // "morning", "midday", "evening", "night", or "custom"
    
    @Published var isLoading = false
    @Published var isOnboardingComplete = false
    
    private let supabase = SupabaseManager.shared
    
    // MARK: - Screen 1: Goal Selection Logic
    
    /// Select a goal option
    func selectGoal(_ goal: String) {
        selectedGoal = goal
        
        // Clear custom text if switching away from custom
        if goal != "custom" {
            customGoalText = ""
        }
    }
    
    /// Check if goal selection is valid
    var isGoalValid: Bool {
        if selectedGoal.isEmpty {
            return false
        }
        
        // If custom is selected, require custom text with at least 10 characters
        if selectedGoal == "custom" {
            return customGoalText.count >= 10
        }
        
        // Predefined goals are always valid
        return true
    }
    
    /// Get the final goal text to save
    var finalGoalText: String {
        if selectedGoal == "custom" {
            return customGoalText
        }
        return selectedGoal
    }
    
    // MARK: - Screen 2: Struggle Selection Logic (UPDATED)
    
    /// The predefined struggle options to display
    let predefinedStruggles = [
        ("distracted", "I get distracted easily"),
        ("falling_back", "I keep falling back to old habits"),
        ("other", "Other")
    ]
    
    /// Select a struggle option
    func selectStruggle(_ struggle: String) {
        selectedStruggle = struggle
        
        // Clear custom text if switching away from other
        if struggle != "other" {
            customStruggleText = ""
        }
    }
    
    /// Check if struggle selection is valid
    var isStruggleValid: Bool {
        if selectedStruggle.isEmpty {
            return false
        }
        
        // If "other" is selected, require custom text with at least 10 characters
        if selectedStruggle == "other" {
            return customStruggleText.count >= 10
        }
        
        // Predefined struggles are always valid
        return true
    }
    
    /// Get the final struggle text to save
    var finalStruggleText: String {
        if selectedStruggle == "other" {
            return customStruggleText
        }
        
        // Return the display text for the selected struggle
        return predefinedStruggles.first(where: { $0.0 == selectedStruggle })?.1 ?? selectedStruggle
    }
    
    // MARK: - Screen 3: Time Selection Logic
    
    /// Select a time preference
    func selectTime(_ time: String) {
        selectedTime = time
    }
    
    // MARK: - Complete Onboarding Flow
    
    /// Complete onboarding: request notifications, save data, and mark as complete
    func completeOnboarding() async {
        isLoading = true
        
        // Step 1: Request notification permission (don't block if denied)
        await requestNotificationPermission()
        
        // Step 2: Save all onboarding data to Supabase
        await saveAllOnboardingData()
        
        // Step 3: Set the flag BEFORE marking onboarding complete
        UserDefaults.standard.set(true, forKey: "justCompletedOnboarding")
        print("✅ justCompletedOnboarding flag set to true")
        
        isLoading = false
        
        print("✅ Onboarding flow completed successfully")
    }
    
    // MARK: - Notification Permission
    
    /// Request notification permission from user
    private func requestNotificationPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            
            // Request authorization
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                print("✅ Notification permission granted")
                
                // Schedule default notification based on selected time
                scheduleDefaultNotification()
            } else {
                print("⚠️ Notification permission denied by user")
            }
            
        } catch {
            print("❌ Error requesting notification permission: \(error)")
        }
    }
    
    /// Schedule a default notification based on user's time preference
    private func scheduleDefaultNotification() {
        let center = UNUserNotificationCenter.current()
        
        // Remove any existing notifications
        center.removeAllPendingNotificationRequests()
        
        // Get notification time based on user preference
        let (hour, minute) = getNotificationTime()
        
        // Create notification content (NO EMOJIS)
        let content = UNMutableNotificationContent()
        content.title = "Time for your check-in"
        content.body = "Let's see how you're doing today"
        content.sound = .default
        
        // Create date components for daily notification
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Create trigger (repeats daily)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "dailyCheckIn",
            content: content,
            trigger: trigger
        )
        
        // Add notification
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                print("✅ Notification scheduled for \(hour):\(String(format: "%02d", minute))")
            }
        }
    }
    
    /// Get notification time based on selected preference
    private func getNotificationTime() -> (hour: Int, minute: Int) {
        switch selectedTime {
        case "morning":
            return (7, 30)  // 7:30 AM
        case "midday":
            return (12, 0)  // 12:00 PM
        case "evening":
            return (18, 0)  // 6:00 PM
        case "night":
            return (20, 0)  // 8:00 PM
        case "custom":
            return (9, 0)   // Default to 9:00 AM for custom (user can change later)
        default:
            return (9, 0)   // Fallback to 9:00 AM
        }
    }
    
    // MARK: - Save Onboarding Data
    
    /// Save all onboarding data to Supabase
    private func saveAllOnboardingData() async {
        guard let userId = supabase.userId else {
            print("❌ No user ID found")
            return
        }
        
        do {
            let goal = finalGoalText
            let struggle = finalStruggleText
            let time = selectedTime
            
            try await supabase.saveOnboardingData(
                goal: goal,
                struggle: struggle,
                preferredTime: time
            )
            
            print("✅ Onboarding data saved: goal=\(goal), struggle=\(struggle), time=\(time)")
            
        } catch {
            print("❌ Save onboarding error: \(error)")
        }
    }
}

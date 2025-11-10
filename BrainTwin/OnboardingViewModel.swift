import Foundation
import Supabase
import Combine
import UserNotifications

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep = 0
    
    // Screen 0: Name Collection (NEW)
    @Published var userName: String = ""
    
    // Screen 1: Age Collection (NEW)
    @Published var userAge: String = ""
    
    // Screen 2: Goal Selection (was Screen 0)
    @Published var selectedGoal: String = ""
    @Published var customGoalText: String = ""
    
    // Screen 3: Struggle Selection (was Screen 1)
    @Published var selectedStruggle: String = ""
    @Published var customStruggleText: String = ""

    // Screen 4: Time Selection (was Screen 2)
    @Published var selectedTime: String = ""
    
    @Published var isLoading = false
    @Published var isOnboardingComplete = false
    
    private let supabase = SupabaseManager.shared
    
    // MARK: - Screen 0: Name Validation
    
    var isNameValid: Bool {
        // At least 2 characters, only letters and spaces
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 50
    }
    
    // MARK: - Screen 1: Age Validation
    
    var isAgeValid: Bool {
        guard let age = Int(userAge) else { return false }
        return age >= 13 && age <= 120
    }
    
    var ageInt: Int? {
        Int(userAge)
    }
    
    // MARK: - Screen 2: Goal Selection Logic
    
    func selectGoal(_ goal: String) {
        selectedGoal = goal
        
        if goal != "custom" {
            customGoalText = ""
        }
    }
    
    var isGoalValid: Bool {
        if selectedGoal.isEmpty {
            return false
        }
        
        if selectedGoal == "custom" {
            return customGoalText.count >= 10
        }
        
        return true
    }
    
    var finalGoalText: String {
        if selectedGoal == "custom" {
            return customGoalText
        }
        return selectedGoal
    }
    
    // MARK: - Screen 3: Struggle Selection Logic
    
    let predefinedStruggles = [
        ("distracted", "I get distracted easily"),
        ("falling_back", "I keep falling back to old habits"),
        ("other", "Other")
    ]
    
    func selectStruggle(_ struggle: String) {
        selectedStruggle = struggle
        
        if struggle != "other" {
            customStruggleText = ""
        }
    }
    
    var isStruggleValid: Bool {
        if selectedStruggle.isEmpty {
            return false
        }
        
        if selectedStruggle == "other" {
            return customStruggleText.count >= 10
        }
        
        return true
    }
    
    var finalStruggleText: String {
        if selectedStruggle == "other" {
            return customStruggleText
        }
        
        return predefinedStruggles.first(where: { $0.0 == selectedStruggle })?.1 ?? selectedStruggle
    }
    
    // MARK: - Screen 4: Time Selection Logic
    
    func selectTime(_ time: String) {
        selectedTime = time
    }
    
    // MARK: - Complete Onboarding Flow
    
    func completeOnboarding() async {
        isLoading = true
        
        // Step 1: Request notification permission
        await requestNotificationPermission()
        
        // Step 2: Save ALL onboarding data (including name and age)
        await saveAllOnboardingData()
        
        // Step 3: Set flag before marking complete
        UserDefaults.standard.set(true, forKey: "justCompletedOnboarding")
        print("✅ justCompletedOnboarding flag set to true")
        
        isLoading = false
        
        print("✅ Onboarding flow completed successfully")
    }
    
    // MARK: - Notification Permission
    
    private func requestNotificationPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                print("✅ Notification permission granted")
                scheduleDefaultNotification()
            } else {
                print("⚠️ Notification permission denied by user")
            }
            
        } catch {
            print("❌ Error requesting notification permission: \(error)")
        }
    }
    
    private func scheduleDefaultNotification() {
        let center = UNUserNotificationCenter.current()
        
        center.removeAllPendingNotificationRequests()
        
        let (hour, minute) = getNotificationTime()
        
        let content = UNMutableNotificationContent()
        content.title = "Time for your check-in"
        content.body = "Let's see how you're doing today"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "dailyCheckIn",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                print("✅ Notification scheduled for \(hour):\(String(format: "%02d", minute))")
            }
        }
    }
    
    private func getNotificationTime() -> (hour: Int, minute: Int) {
        switch selectedTime {
        case "morning":
            return (7, 30)
        case "midday":
            return (12, 0)
        case "evening":
            return (18, 0)
        case "night":
            return (20, 0)
        case "custom":
            return (9, 0)
        default:
            return (9, 0)
        }
    }
    
    // MARK: - Save Onboarding Data (UPDATED - includes name and age)
    
    private func saveAllOnboardingData() async {
        guard let userId = supabase.userId else {
            print("❌ No user ID found")
            return
        }
        
        do {
            let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let age = ageInt ?? 0
            let goal = finalGoalText
            let struggle = finalStruggleText
            let time = selectedTime
            
            // Save to Supabase with name and age
            try await supabase.saveOnboardingData(
                name: name,
                age: age,
                goal: goal,
                struggle: struggle,
                preferredTime: time
            )
            
            print("✅ Onboarding data saved: name=\(name), age=\(age), goal=\(goal), struggle=\(struggle), time=\(time)")
            
        } catch {
            print("❌ Save onboarding error: \(error)")
        }
    }
}

import Foundation
import Supabase
import Combine
import SwiftUI

@MainActor
class InsightsViewModel: ObservableObject {
    @Published var completedDates: [Date] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var isLoading = false
    
    private let supabase = SupabaseManager.shared
    
    func loadStreakData() async {
        guard let userId = supabase.userId else {
            print("❌ No user ID found")
            return
        }
        
        isLoading = true
        
        do {
            // Fetch meter data for streaks
            let meterData: MeterResponse = try await supabase.getMeterData(userId: userId)
            currentStreak = meterData.streak
            longestStreak = meterData.streak // You can add longestStreak to backend later
            
            // Fetch completed dates for this month
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            
            let startDateString = formatter.string(from: startOfMonth)
            let endDateString = formatter.string(from: endOfMonth)
            
            struct CompletedTask: Decodable {
                let date: String
                let completed_at: String?
            }
            
            let tasks: [CompletedTask] = try await supabase.client
                .from("daily_tasks")
                .select()
                .eq("user_id", value: userId)
                .gte("date", value: startDateString)
                .lte("date", value: endDateString)
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            // Convert to Date objects
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            completedDates = tasks.compactMap { task in
                dateFormatter.date(from: task.date)
            }
            
            print("✅ Loaded \(completedDates.count) completed days this month")
            
        } catch {
            print("❌ Load streak error: \(error)")
        }
        
        isLoading = false
    }
}

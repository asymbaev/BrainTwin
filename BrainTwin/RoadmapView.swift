import SwiftUI

struct RoadmapView: View {
    @Environment(\.dismiss) private var dismiss
    let completedCount: Int
    let onStartDay: () -> Void
    
    var currentDay: Int {
        completedCount + 1 // Next day to complete
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.purple.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Text("Your Journey")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    if completedCount == 0 {
                        Text("Ready to begin your transformation")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("\(completedCount) day\(completedCount == 1 ? "" : "s") completed")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Roadmap cards
                VStack(spacing: 20) {
                    // Show past 2 days (if they exist)
                    if completedCount >= 2 {
                        RoadmapCard(
                            dayNumber: completedCount - 1,
                            title: "Previous Day",
                            isCompleted: true,
                            isCurrent: false
                        )
                    }
                    
                    if completedCount >= 1 {
                        RoadmapCard(
                            dayNumber: completedCount,
                            title: "Completed",
                            isCompleted: true,
                            isCurrent: false
                        )
                    }
                    
                    // Current day (highlighted)
                    RoadmapCard(
                        dayNumber: currentDay,
                        title: currentDay == 1 ? "Begin Your Journey" : "Today's Challenge",
                        isCompleted: false,
                        isCurrent: true
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Start button
                Button {
                    onStartDay()
                    dismiss()
                } label: {
                    Text("Start My Day")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.yellow)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Roadmap Card Component

struct RoadmapCard: View {
    let dayNumber: Int
    let title: String
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Day icon
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.yellow : (isCompleted ? Color.green : Color.gray))
                    .frame(width: 60, height: 60)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                } else {
                    Text("\(dayNumber)")
                        .font(.title3.bold())
                        .foregroundColor(isCurrent ? .black : .white)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("DAY \(dayNumber)")
                    .font(.caption.bold())
                    .foregroundColor(isCurrent ? .yellow : .white.opacity(0.6))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrent ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrent ? Color.yellow : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    RoadmapView(completedCount: 5) {
        print("Start day tapped")
    }
}

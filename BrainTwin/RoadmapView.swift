import SwiftUI
import os

struct RoadmapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    let completedCount: Int
    let onStartDay: () -> Void

    @State private var lineProgress: CGFloat = 0
    @State private var showCheckmarks: Set<Int> = []
    @State private var currentDayScale: CGFloat = 1.0
    @State private var subtlePulse = false

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var currentDay: Int { completedCount + 1 }

    // Shows 2 previous, today, and 2 next
    var allDays: [DayItem] {
        var days: [DayItem] = []
        if completedCount >= 2 { days.append(.init(number: completedCount - 1, status: .completed)) }
        if completedCount >= 1 { days.append(.init(number: completedCount, status: .completed)) }
        days.append(.init(number: currentDay, status: .current))
        days.append(.init(number: currentDay + 1, status: .locked))
        if days.count < 5 { days.append(.init(number: currentDay + 2, status: .locked)) }
        return days
    }

    private var headerProgress: CGFloat {
        let denom: CGFloat = 6.0
        return min(max(CGFloat(completedCount % 7) / denom, 0), 1)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if colorScheme == .dark {
                RadialGradient(
                    colors: [Color(white: 0.04), Color.black],
                    center: .center, startRadius: 0, endRadius: 500
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // MARK: Header ring
                VStack(spacing: 12) {
                    CircularStreakRing(
                        progress: headerProgress,
                        pulse: subtlePulse,
                        colorScheme: colorScheme
                    )
                    .frame(width: 112, height: 112)
                    .padding(.top, 44)

                    Text(completedCount == 0
                         ? "Ready to begin your transformation"
                         : "\(completedCount) day\(completedCount == 1 ? "" : "s") completed")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.bottom, 8)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                        subtlePulse.toggle()
                    }
                }

                Spacer(minLength: 8)

                // MARK: Journey map (new sleek rail)
                ScrollView(.vertical, showsIndicators: false) {
                    TimelineColumn(
                        items: allDays,
                        colorScheme: colorScheme,
                        lineProgress: lineProgress
                    ) { day in
                        DayCardView(
                            day: day,
                            showCheckmark: showCheckmarks.contains(day.number),
                            scale: day.status == .current ? currentDayScale : 1.0
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: 450)

                Spacer()

                Button {
                    onStartDay()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Text("Start My Day").font(.headline)
                        Image(systemName: "arrow.right.circle.fill").font(.title3)
                    }
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.appAccent)
                    .cornerRadius(16)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.2)) { lineProgress = 1.0 }

        for (index, day) in allDays.enumerated() where day.status == .completed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(index) * 0.25) {
                withAnimation(.spring(duration: 0.4, bounce: 0.6)) {
                    _ = showCheckmarks.insert(day.number)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                currentDayScale = 1.05
            }
        }
    }
}

// MARK: - Sleek timeline rail with nodes
private struct TimelineColumn<Content: View>: View {
    let items: [DayItem]
    let colorScheme: ColorScheme
    let lineProgress: CGFloat
    let content: (DayItem) -> Content

    private let railWidth: CGFloat = 56           // reserved left column
    private let spineWidth: CGFloat = 3           // line thickness
    private let nodeSize: CGFloat = 14            // node diameter
    private let rowSpacing: CGFloat = 16

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left rail with animated spine
            ZStack(alignment: .top) {
                GeometryReader { geo in
                    let fullH = geo.size.height
                    Capsule()
                        .fill(LinearGradient(
                            colors: [
                                Color.appAccent.opacity(colorScheme == .dark ? 0.9 : 0.7),
                                Color.appAccent.opacity(0.35)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: spineWidth)
                        .frame(height: fullH * max(0.001, lineProgress), alignment: .top)
                        .mask(
                            // Soft fade at top & bottom so the rail never has hard ends
                            LinearGradient(
                                colors: [.clear, .black, .black, .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                            .padding(.vertical, 10)
                        )
                        .shadow(color: Color.appAccent.opacity(colorScheme == .dark ? 0.35 : 0.18),
                                radius: 6, x: 0, y: 0)
                        .animation(.easeInOut(duration: 1.2), value: lineProgress)
                }

                // Nodes aligned to each row midY
                VStack(spacing: rowSpacing) {
                    ForEach(items, id: \.number) { item in
                        NodeView(status: item.status,
                                size: nodeSize,
                                colorScheme: colorScheme)
                        .frame(height: 96, alignment: .center) // matches card height below
                    }
                }
            }
            .frame(width: railWidth)

            // Cards column
            VStack(spacing: rowSpacing) {
                ForEach(items, id: \.number) { item in
                    content(item)
                        .frame(height: 96) // stable height = perfect node centering
                        .overlay(
                            // short connector from rail to card
                            HStack(spacing: 0) {
                                Capsule()
                                    .fill(Color.appCardBorder)
                                    .frame(width: 10, height: 2)
                                    .opacity(item.status == .locked ? 0.5 : 0.9)
                                Spacer()
                            }
                            .padding(.leading, -railWidth - 10),
                            alignment: .leading
                        )
                }
            }
        }
    }
}

private struct NodeView: View {
    let status: DayStatus
    let size: CGFloat
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // soft outer glow
            Circle()
                .fill(Color.clear)
                .frame(width: size * 1.8, height: size * 1.8)
                .shadow(color: glowColor.opacity(0.45), radius: 8)

            // ring + core
            Circle()
                .strokeBorder(ringColor, lineWidth: 3)
                .background(Circle().fill(coreColor))
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    private var coreColor: Color {
        switch status {
        case .completed: return Color.green.opacity(0.9)
        case .current:   return Color.appAccent
        case .locked:    return Color.appCardBorder
        }
    }

    private var ringColor: Color {
        switch status {
        case .completed: return Color.green.opacity(0.7)
        case .current:   return Color.appAccent.opacity(0.8)
        case .locked:    return Color.white.opacity(0.35)
        }
    }

    private var glowColor: Color {
        switch status {
        case .completed: return Color.green
        case .current:   return Color.appAccent
        case .locked:    return Color.clear
        }
    }
}

// MARK: - Circular Streak Ring (unchanged)
private struct CircularStreakRing: View {
    let progress: CGFloat // 0…1
    let pulse: Bool
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            Circle().stroke(Color.appCardBorder, lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.6, blue: 0.2),   // Warm orange
                            Color(red: 1.0, green: 0.84, blue: 0.0),  // Gold
                            Color(red: 1.0, green: 0.6, blue: 0.2)    // Warm orange
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.appAccent.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 6)
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)

            ZStack {
                Circle().fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.6))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color.appAccent)
            }
            .padding(20)
            .scaleEffect(pulse ? 1.02 : 0.98)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Day Card (unchanged from your version)
struct DayCardView: View {
    let day: DayItem
    let showCheckmark: Bool
    let scale: CGFloat
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Circle icon
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: day.status == .current ? 3 : 2)
                    )
                    .shadow(
                        color: day.status == .current && colorScheme == .dark
                            ? Color.appAccent.opacity(0.6)
                            : .clear,
                        radius: 12
                    )

                if day.status == .completed && showCheckmark {
                    Image(systemName: "checkmark")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .scaleEffect(showCheckmark ? 1.0 : 0.1)
                }

                if day.status == .current {
                    Text("\(day.number)")
                        .font(.title2.bold())
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                }

                if day.status == .locked {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .scaleEffect(scale)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("DAY \(day.number)")
                    .font(.caption.bold())
                    .foregroundColor(textColor)

                Text(title)
                    .font(.headline)
                    .foregroundColor(day.status == .locked ? .appTextSecondary : .appTextPrimary)
            }

            Spacer()

            if day.status == .current {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(Color.appAccent)
                    .opacity(scale > 1.0 ? 1.0 : 0.5)
            }
        }
        .padding(16)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(day.status == .current ? Color.appAccent : Color.appCardBorder,
                        lineWidth: day.status == .current ? 2 : 1)
        )
        .cornerRadius(20)
        .opacity(day.status == .locked ? 0.5 : 1.0)
    }

    private var backgroundColor: Color {
        switch day.status {
        case .completed: return Color.green
        case .current:   return Color.appAccent
        case .locked:    return Color.appCardBorder
        }
    }

    private var borderColor: Color {
        day.status == .current ? Color.appAccent.opacity(0.3) : Color.clear
    }

    private var textColor: Color {
        day.status == .current ? Color.appAccent : .appTextSecondary
    }

    private var cardBackground: Color {
        day.status == .current
            ? Color.appCardBackground
            : Color.appCardBackground.opacity(0.5)
    }

    private var title: String {
        switch day.status {
        case .completed: return "Completed"
        case .current:   return day.number == 1 ? "Begin Your Journey" : "Today's Challenge"
        case .locked:    return "Locked"
        }
    }
}

// MARK: - Models
struct DayItem: Hashable {
    let number: Int
    let status: DayStatus
}

enum DayStatus { case completed, current, locked }

#Preview {
    RoadmapView(completedCount: 1) { print("Start") }
}

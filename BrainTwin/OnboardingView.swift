import SwiftUI
import SuperwallKit

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Binding var isOnboardingComplete: Bool
    @State private var showProfileSetup = false
    @State private var setupComplete = false
    
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @Environment(\.colorScheme) var colorScheme
    
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
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
            }
            
            AdaptiveStarfieldView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator - NOW 5 STEPS
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(index <= viewModel.currentStep ? Color.appAccent : Color.appTextTertiary)
                            .frame(height: 4)
                    }
                }
                .padding()
                
                // Content
                TabView(selection: $viewModel.currentStep) {
                    screen0_NameCollection.tag(0)      // NEW
                    screen1_AgeCollection.tag(1)       // NEW
                    screen2_GoalSelection.tag(2)       // Was 0
                    screen3_StruggleSelection.tag(3)   // Was 1
                    screen4_TimeSelection.tag(4)       // Was 2
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .fullScreenCover(isPresented: $showProfileSetup) {
                ProfileSetupAnimationView(isComplete: $setupComplete)
                    .onChange(of: setupComplete) { done in
                        if done {
                            print("🎉 Animation complete! Setting onboarding complete...")
                            
                            isOnboardingComplete = true
                            UserDefaults.standard.set(true, forKey: "justCompletedOnboarding")
                            
                            showProfileSetup = false
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showPaywall()
                            }
                        }
                    }
                    .interactiveDismissDisabled(true)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
    
    // MARK: - Paywall (UPDATED - Age-based routing)
    private func showPaywall() {
        // Determine campaign based on user's age
        let campaign = determineCampaignByAge(age: viewModel.ageInt ?? 25)
        
        print("🎯 Triggering Superwall campaign: \(campaign) for age: \(viewModel.ageInt ?? 25)")
        
        // Register the age-specific campaign
        Superwall.shared.register(placement: campaign)
        
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await checkIfUserSubscribed()
        }
    }
    
    /// Determines which Superwall campaign to trigger based on user's age
    private func determineCampaignByAge(age: Int) -> String {
        switch age {
        case 0..<18:
            return "Under 18"
        case 18...22:
            return "18-22"
        case 23...28:
            return "23-28"
        case 29...40:
            return "29-40"
        default: // 41+
            return "Over 40"
        }
    }

    private func checkIfUserSubscribed() async {
        await SubscriptionManager.shared.refreshSubscription()
        
        if SubscriptionManager.shared.isSubscribed {
            await MainActor.run {
                completeOnboarding()
            }
        } else {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            await MainActor.run {
                if !SubscriptionManager.shared.isSubscribed {
                    print("⚠️ User didn't subscribe, showing paywall again...")
                    showPaywall()
                } else {
                    completeOnboarding()
                }
            }
        }
    }

    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "justCompletedOnboarding")
        print("✅ Onboarding complete - user is subscribed!")
    }
    
    // MARK: - Screen 0: Name Collection (NEW)
    
    private var screen0_NameCollection: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("What's your name?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Let's personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            // Name Input
            VStack(alignment: .leading, spacing: 12) {
                TextField("Enter your first name", text: $viewModel.userName)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .foregroundColor(.appTextPrimary)
                    .accentColor(.appAccent)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                viewModel.userName.isEmpty ? Color.appCardBorder : Color.appAccent,
                                lineWidth: viewModel.userName.isEmpty ? 1 : 2
                            )
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                
                if !viewModel.userName.isEmpty && !viewModel.isNameValid {
                    Text("Please enter at least 2 characters")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 1
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isNameValid)
            .opacity(viewModel.isNameValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 1: Age Collection (NEW)
    
    private var screen1_AgeCollection: some View {
        VStack(spacing: 24) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 0
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("How old are you?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("This helps us personalize your journey")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            // Age Input
            VStack(alignment: .leading, spacing: 12) {
                TextField("Enter your age", text: $viewModel.userAge)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .foregroundColor(.appTextPrimary)
                    .accentColor(.appAccent)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                viewModel.userAge.isEmpty ? Color.appCardBorder : Color.appAccent,
                                lineWidth: viewModel.userAge.isEmpty ? 1 : 2
                            )
                    )
                
                if !viewModel.userAge.isEmpty && !viewModel.isAgeValid {
                    Text("Please enter a valid age (13-120)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
                
                Text("We use this to personalize content and track demographics")
                    .font(.caption)
                    .foregroundColor(.appTextTertiary)
                    .padding(.leading, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 2
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isAgeValid)
            .opacity(viewModel.isAgeValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 2: Goal Selection (Was Screen 0)
    
    private var screen2_GoalSelection: some View {
        VStack(spacing: 24) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("What's your main goal?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Choose one or describe your own")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            // Goal Options
            VStack(spacing: 16) {
                GoalOptionButton(
                    title: "Build better habits",
                    isSelected: viewModel.selectedGoal == "Build better habits",
                    action: { viewModel.selectGoal("Build better habits") }
                )
                
                GoalOptionButton(
                    title: "Overcome procrastination",
                    isSelected: viewModel.selectedGoal == "Overcome procrastination",
                    action: { viewModel.selectGoal("Overcome procrastination") }
                )
                
                GoalOptionButton(
                    title: "Reduce anxiety/stress",
                    isSelected: viewModel.selectedGoal == "Reduce anxiety/stress",
                    action: { viewModel.selectGoal("Reduce anxiety/stress") }
                )
                
                // Custom Goal Option
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        viewModel.selectGoal("custom")
                    } label: {
                        HStack {
                            Text("Other - Set your own goal")
                                .font(.body)
                                .foregroundColor(.appTextPrimary)
                            
                            Spacer()
                            
                            Circle()
                                .strokeBorder(Color.appCardBorder, lineWidth: 2)
                                .background(
                                    Circle()
                                        .fill(viewModel.selectedGoal == "custom" ? Color.appAccent : Color.clear)
                                )
                                .frame(width: 24, height: 24)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.appCardBorder, lineWidth: 1)
                        )
                    }
                    
                    if viewModel.selectedGoal == "custom" {
                        TextField("e.g., Build discipline to finish my startup tasks", text: $viewModel.customGoalText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .foregroundColor(.appTextPrimary)
                            .accentColor(.appAccent)
                            .placeholder(when: viewModel.customGoalText.isEmpty) {
                                Text("e.g., Build discipline to finish my startup tasks")
                                    .foregroundColor(.appTextTertiary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appCardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
                            )
                            .lineLimit(2...4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 3
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isGoalValid)
            .opacity(viewModel.isGoalValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 3: Struggle Selection (Was Screen 1)
    
    private var screen3_StruggleSelection: some View {
        VStack(spacing: 24) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 2
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("What's your biggest struggle?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("This helps us personalize your journey")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            // Struggle Options
            VStack(spacing: 12) {
                StruggleOptionButton(
                    title: "I get distracted easily",
                    isSelected: viewModel.selectedStruggle == "I get distracted easily",
                    action: { viewModel.selectStruggle("I get distracted easily") }
                )
                
                StruggleOptionButton(
                    title: "I keep falling back to old habits",
                    isSelected: viewModel.selectedStruggle == "I keep falling back to old habits",
                    action: { viewModel.selectStruggle("I keep falling back to old habits") }
                )
                
                StruggleOptionButton(
                    title: "I start strong but lose motivation",
                    isSelected: viewModel.selectedStruggle == "I start strong but lose motivation",
                    action: { viewModel.selectStruggle("I start strong but lose motivation") }
                )
                
                StruggleOptionButton(
                    title: "I feel overwhelmed",
                    isSelected: viewModel.selectedStruggle == "I feel overwhelmed",
                    action: { viewModel.selectStruggle("I feel overwhelmed") }
                )
                
                // Custom Struggle Option
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        viewModel.selectStruggle("other")
                    } label: {
                        HStack {
                            Text("Other")
                                .font(.body)
                                .foregroundColor(.appTextPrimary)
                            
                            Spacer()
                            
                            Circle()
                                .strokeBorder(Color.appCardBorder, lineWidth: 2)
                                .background(
                                    Circle()
                                        .fill(viewModel.selectedStruggle == "other" ? Color.appAccent : Color.clear)
                                )
                                .frame(width: 24, height: 24)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.appCardBorder, lineWidth: 1)
                        )
                    }
                    
                    if viewModel.selectedStruggle == "other" {
                        TextField("Describe your biggest challenge...", text: $viewModel.customStruggleText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .foregroundColor(.appTextPrimary)
                            .accentColor(.appAccent)
                            .placeholder(when: viewModel.customStruggleText.isEmpty) {
                                Text("Describe your biggest challenge...")
                                    .foregroundColor(.appTextTertiary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appCardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
                            )
                            .lineLimit(2...4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 4
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isStruggleValid)
            .opacity(viewModel.isStruggleValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 4: Time Selection (Was Screen 2)
    
    private var screen4_TimeSelection: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 3
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Text("When do you work best?")
                            .font(.title.bold())
                            .foregroundColor(.appTextPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("We'll remind you at the right time")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Time Options
                    VStack(spacing: 12) {
                        TimeOptionButton(
                            title: "Morning",
                            subtitle: "6:00 AM - 9:00 AM",
                            timeValue: "morning",
                            isSelected: viewModel.selectedTime == "morning",
                            action: { viewModel.selectTime("morning") }
                        )
                        
                        TimeOptionButton(
                            title: "Midday",
                            subtitle: "12:00 PM - 3:00 PM",
                            timeValue: "midday",
                            isSelected: viewModel.selectedTime == "midday",
                            action: { viewModel.selectTime("midday") }
                        )
                        
                        TimeOptionButton(
                            title: "Evening",
                            subtitle: "5:00 PM - 8:00 PM",
                            timeValue: "evening",
                            isSelected: viewModel.selectedTime == "evening",
                            action: { viewModel.selectTime("evening") }
                        )
                        
                        TimeOptionButton(
                            title: "Night",
                            subtitle: "8:00 PM - 11:00 PM",
                            timeValue: "night",
                            isSelected: viewModel.selectedTime == "night",
                            action: { viewModel.selectTime("night") }
                        )
                        
                        TimeOptionButton(
                            title: "I'll set it later",
                            subtitle: "Choose your own time",
                            timeValue: "custom",
                            isSelected: viewModel.selectedTime == "custom",
                            action: { viewModel.selectTime("custom") }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Notification Info
                    if !viewModel.selectedTime.isEmpty {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.appAccent)
                                Text("We'll ask for notification permission")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                        .padding(.top, 8)
                        .transition(.opacity)
                    }
                }
            }
            
            // Complete Button
            Button {
                Task {
                    await viewModel.completeOnboarding()
                    setupComplete = false
                    showProfileSetup = true
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Complete Setup")
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(viewModel.selectedTime.isEmpty || viewModel.isLoading)
            .opacity(viewModel.selectedTime.isEmpty || viewModel.isLoading ? 0.5 : 1)
            .padding()
        }
    }
}

// MARK: - Button Components (unchanged)

struct GoalOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.appTextPrimary)
                
                Spacer()
                
                Circle()
                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.clear)
                    )
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
            )
        }
    }
}

struct StruggleOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Circle()
                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.clear)
                    )
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
            )
        }
    }
}

struct TimeOptionButton: View {
    let title: String
    let subtitle: String
    let timeValue: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.appTextPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                Circle()
                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.clear)
                    )
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
            )
        }
    }
}

struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccent)
            .cornerRadius(12)
            .shadow(color: Color.appAccent.opacity(0.3), radius: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct AdaptiveStarfieldView: View {
    @State private var stars: [Star] = []
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(stars) { star in
                    Circle()
                        .fill(starColor)
                        .frame(width: star.size, height: star.size)
                        .position(x: star.x, y: star.y)
                        .opacity(star.opacity * opacityMultiplier)
                        .blur(radius: star.blur)
                }
            }
            .onAppear {
                generateStars(in: geometry.size)
            }
        }
    }
    
    private var starColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.3)
    }
    
    private var opacityMultiplier: Double {
        colorScheme == .dark ? 1.0 : 0.3
    }
    
    private func generateStars(in size: CGSize) {
        var generatedStars: [Star] = []
        
        for i in 0..<150 {
            let star = Star(
                id: i,
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 0.5...2.5),
                opacity: Double.random(in: 0.2...0.9),
                blur: CGFloat.random(in: 0...1.5),
                animationDelay: Double.random(in: 0...3)
            )
            generatedStars.append(star)
        }
        
        stars = generatedStars
        
        for (index, star) in stars.enumerated() {
            animateStar(at: index, delay: star.animationDelay)
        }
    }
    
    private func animateStar(at index: Int, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: Double.random(in: 1.5...3.5)).repeatForever(autoreverses: true)) {
                if index < stars.count {
                    stars[index].opacity = Double.random(in: 0.2...0.9)
                }
            }
        }
    }
}

struct Star: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    var opacity: Double
    let blur: CGFloat
    let animationDelay: Double
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}

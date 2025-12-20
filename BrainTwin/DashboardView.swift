import SwiftUI
import Combine
import Supabase
import os

struct DashboardView: View {
    @StateObject private var hackViewModel: DailyHackViewModel
    @EnvironmentObject var meterDataManager: MeterDataManager

    init() {
        // ✅ CRITICAL: Initialize with pre-loaded hack for INSTANT display
        let preloadedHack = MeterDataManager.shared.todaysHack
        _hackViewModel = StateObject(wrappedValue: DailyHackViewModel(preloadedHack: preloadedHack))

        print("🚀 [Dashboard Init] ==================")
        print("   MeterDataManager.todaysHack: \(MeterDataManager.shared.todaysHack != nil ? "✅ AVAILABLE" : "❌ NIL")")
        print("   Preloaded hack: \(preloadedHack != nil ? "✅ YES" : "❌ NO")")
        if let hack = preloadedHack {
            print("   Hack name: \(hack.hackName)")
        }
        print("==================")
    }
    @Environment(\.colorScheme) var colorScheme // Moved here as per instruction
    
    // Appearance override (System/Light/Dark)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("userName") private var userName: String = ""  // ✅ NEW: Get user's name
    @AppStorage("lastViewedCard") private var lastViewedCard: String = "progress"  // ✅ NEW: Remember user preference
    
    @State private var errorText: String?
    @State private var isCardExpanded = false
    @State private var weekDays: [(day: String, date: Int, isCompleted: Bool)] = []
    @State private var showListenMode = false
    @State private var showReadMode = false
    @State private var pulse = false
    
    // ✅ NEW: Flip card animation states
    @State private var showingProgressCard = true  // true = Progress, false = Streak
    @State private var isFlipping = false
    @State private var autoRotationTimer: Timer?
    @State private var isFirstFlip = true  // ✅ Track if this is the first auto-flip
    
    // ✅ NEW: Profile sheet state
    @State private var showProfileSheet = false
    
    // ✅ NEW: Profile image state
    @AppStorage("profileImageData") private var profileImageData: Data?
    @State private var profileImage: UIImage?
    
    private var supabase: SupabaseManager { SupabaseManager.shared }
    
    // Computed color scheme based on user preference
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System
        }
    }
    
    // MARK: - Responsive Sizing for Pro Max
    // Uses min+percentage formula: stays ~200pt on Pro, grows to ~230pt on Pro Max
    private var responsiveCardHeight: CGFloat {
        max(200, UIScreen.main.bounds.height * 0.24)
    }
    
    private var responsiveSpacing: CGFloat {
        max(20, UIScreen.main.bounds.height * 0.025)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background (warm off-white in light, black in dark)
                Color.appBackground.ignoresSafeArea()
                
                // Subtle depth gradient (only in dark mode)
                darkModeDepthGradient

                ScrollView {
                    VStack(spacing: responsiveSpacing) {
                        // Greeting header
                        greetingHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        
                        // ✅ NEW: Flip card (replaces horizontal carousel)
                        flipCardContainer
                        
                        // Hero: Today's Brain Hack Card
                        todayHackCard
                            .padding(.horizontal)
                        
                        errorSection
                    }
                    .padding(.bottom, 20)
                }
                .onAppear {
                    // Initialize card based on last viewed preference
                    showingProgressCard = (lastViewedCard == "progress")
                    startAutoRotation()
                    
                    // Fetch user name from Supabase
                    Task {
                        do {
                            if let fetchedName = try await SupabaseManager.shared.fetchUserName() {
                                // Update UserDefaults cache with backend value
                                userName = fetchedName
                                print("✅ [Dashboard] Synced name from backend: '\(fetchedName)'")
                            } else {
                                print("ℹ️ [Dashboard] No name found in backend")
                            }
                        } catch {
                            print("❌ [Dashboard] Failed to fetch name from backend: \(error)")
                            // Keep using cached UserDefaults value
                        }
                    }
                }
                .onDisappear {
                    stopAutoRotation()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(preferredColorScheme) // Apply user preference
            .task {
                // ✅ Data should already be pre-fetched during animation!
                // These calls will use cached data (instant, no network call)
                if meterDataManager.meterData == nil {
                    print("⚠️ Cache miss: Meter data not found (pre-fetch may have failed)")
                    await meterDataManager.fetchMeterData()
                } else {
                    print("⚡️ Using pre-fetched meter data - INSTANT!")
                }
                
                // This will use cached hack data if available (see DailyHackViewModel)
                await hackViewModel.loadTodaysHack()
                
                // ✅ NEW: Restore profile picture if missing (e.g. after reinstall)
                if profileImageData == nil {
                    print("🔍 [Dashboard] No local profile picture. Checking backend...")
                    do {
                        if let urlString = try await SupabaseManager.shared.fetchProfilePictureURL() {
                            if let image = try await SupabaseManager.shared.downloadProfilePicture(from: urlString) {
                                if let data = image.jpegData(compressionQuality: 0.8) {
                                    profileImageData = data
                                    profileImage = image
                                    print("✅ [Dashboard] Restored profile picture from backend")
                                }
                            }
                        } else {
                            print("ℹ️ [Dashboard] No profile picture found in backend")
                        }
                    } catch {
                        print("❌ [Dashboard] Failed to restore profile picture: \(error)")
                    }
                }
            }
            .refreshable {
                await meterDataManager.fetchMeterData(force: true)
                await hackViewModel.loadTodaysHack()
                generateWeekData()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshDashboard"))) { _ in
                Task {
                    await meterDataManager.fetchMeterData(force: true)
                    await hackViewModel.loadTodaysHack()
                    generateWeekData()
                }
            }
            .onAppear {
                generateWeekData()
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
            .onChange(of: meterDataManager.isTodayHackComplete) { _ in
                generateWeekData()
            }
            // ✅ NEW: Watch for profile image changes (immediate sync)
            .onChange(of: profileImageData) { newData in
                if let data = newData, let image = UIImage(data: data) {
                    profileImage = image
                    print("✅ [Dashboard] Profile image updated immediately")
                }
            }
        }
        .fullScreenCover(isPresented: $showListenMode) {
            if let hack = hackViewModel.todaysHack {
                DailyHackView(
                    autoPlayVoice: true,
                    preloadedHack: hack,
                    preGeneratedAudioUrls: hack.audioUrls ?? []
                )
            }
        }
        .fullScreenCover(isPresented: $showReadMode) {
            if let hack = hackViewModel.todaysHack {
                DailyHackView(
                    autoPlayVoice: false,
                    preloadedHack: hack,
                    preGeneratedAudioUrls: hack.audioUrls ?? []
                )
            }
        }
        .fullScreenCover(isPresented: $showProfileSheet) {
            NavigationStack {
                ProfileSheetView()
                    .environmentObject(meterDataManager)
            }
        }
    }
    
    // MARK: - Dark Mode Depth Gradient (only shows in dark mode)
    @ViewBuilder
    private var darkModeDepthGradient: some View {
        // Only add radial gradient in dark mode for depth
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
        .opacity(colorScheme == .dark ? 1 : 0)
    }
    
    // MARK: - Meter Section
    @ViewBuilder
    private var meterSection: some View {
        if let data = meterDataManager.meterData {
            circularProgressView(data: data)
        } else if meterDataManager.isLoading {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appAccent)
                .padding()
        }
    }
    
    // MARK: - Error Section
    @ViewBuilder
    private var errorSection: some View {
        if let error = meterDataManager.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .padding()
        }
    }

    // MARK: - Hack Card
    private var todayHackCard: some View {
        VStack(spacing: 0) {
            hackCardMainButton
            
            if isCardExpanded {
                hackCardExpandedContent
            }
        }
        .background(Color.appCardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 10, y: 5)
    }
    
    // Shadow adapts to mode
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08)
    }
    
    // Hack Card - Main Button
    private var hackCardMainButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isCardExpanded.toggle()
            }
        } label: {
            hackCardContent
        }
    }
    
    // Hack Card - Content
    private var hackCardContent: some View {
        ZStack {
            hackCardBackground
            hackCardOverlay
            hackCardText
        }
        .frame(height: responsiveCardHeight)
    }
    
    // Hack Card - Background Image
    private var hackCardBackground: some View {
        CachedAsyncImage(url: ImageService.getTodaysImage()) {
            // Fallback gradient (only shown if image not cached)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(white: 0.08), Color(white: 0.04)]
                    : [Color(hex: "#FFE7D6"), Color(hex: "#FFF8F0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .aspectRatio(contentMode: .fill)
        .frame(height: responsiveCardHeight)
        .clipped()
    }
    
    // Hack Card - Dark Overlay
    private var hackCardOverlay: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.50), Color.black.opacity(0.80)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // Hack Card - Text Content
    private var hackCardText: some View {
        VStack(alignment: .leading, spacing: 12) {
            hackCardHeader
            Spacer()
            hackCardTitle
            hackCardTags
        }
        .padding()
    }
    
    // Hack Card - Header Row
    private var hackCardHeader: some View {
        HStack {
            if meterDataManager.isTodayHackComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.6), radius: 4)
            }

            Text("TODAY'S BRAIN HACK • 1 MIN")
                .font(.caption.bold())
                .foregroundColor(.white)

            Spacer()

            Image(systemName: isCardExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(.white.opacity(0.7))
                .font(.title3)
        }
    }
    
    // Hack Card - Title
    @ViewBuilder
    private var hackCardTitle: some View {
        if let hack = hackViewModel.todaysHack {
            Text(hack.hackName)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(isCardExpanded ? nil : 2)
        } else if hackViewModel.errorMessage != nil {
            Text("Tap to try again")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
        } else {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.white)
                Text("Loading your hack...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }
    
    // Hack Card - Tags
    private var hackCardTags: some View {
        HStack(spacing: 8) {
            miniTag(text: "FOCUS")
            miniTag(text: "DISCIPLINE")
            miniTag(text: "MOTIVATION")
        }
    }
    
    // Hack Card - Expanded Content
    private var hackCardExpandedContent: some View {
        VStack(spacing: 16) {
            if hackViewModel.todaysHack != nil {
                HStack(spacing: 12) {
                    listenButton
                    readButton
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(Color.appGlassOverlay)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // Listen Button (Primary - Gold Accent)
    private var listenButton: some View {
        Button {
            showListenMode = true
        } label: {
            HStack {
                Image(systemName: "headphones")
                Text("Listen")
            }
            .font(.subheadline.bold())
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.appAccentGradient)
            .cornerRadius(12)
            .shadow(color: Color.appAccent.opacity(0.3), radius: 8)
        }
    }
    
    // Read Button (Secondary - Glass)
    private var readButton: some View {
        Button {
            showReadMode = true
        } label: {
            HStack {
                Image(systemName: "book")
                Text("Read")
            }
            .font(.subheadline.bold())
            .foregroundColor(.appTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.appGlassOverlay)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Horizontal Cards Carousel
    
    private var horizontalCardsCarousel: some View {
        VStack(spacing: 12) {
            TabView {
                // Progress Card
                progressGradientCard
                    .padding(.horizontal, 16)
                
                // Streak Card
                streakGradientCard
                    .padding(.horizontal, 16)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 320)
        }
    }
    
    // Progress Gradient Card
    private var progressGradientCard: some View {
        ZStack {
            // Vibrant gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.8, blue: 0.9),   // Cyan
                    Color(red: 0.4, green: 0.6, blue: 1.0),   // Blue
                    Color(red: 0.8, green: 0.4, blue: 1.0),   // Purple
                    Color(red: 1.0, green: 0.5, blue: 0.8),   // Pink
                    Color(red: 1.0, green: 0.7, blue: 0.5)    // Peach/Orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glassmorphism overlay
            Color.white.opacity(0.15)
            
            // Content
            VStack(spacing: 6) {
                Text("Rewire Progress")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.top, 12)
                
                meterSection
                    .padding(.bottom, 8)
            }
        }
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    // Streak Gradient Card  
    private var streakGradientCard: some View {
        streakCalendarView
    }
    
    // MARK: - 3D Flip Card Animation
    
    private var flipCardContainer: some View {
        ZStack {
            // Back card (Streak) - shows when rotated
            if !showingProgressCard || isFlipping {
                streakGradientCard
                    .rotation3DEffect(
                        .degrees(showingProgressCard ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .opacity(showingProgressCard ? 0 : 1)
            }
            
            // Front card (Progress) - shows by default
            if showingProgressCard || isFlipping {
                progressGradientCard
                    .rotation3DEffect(
                        .degrees(showingProgressCard ? 0 : -180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .opacity(showingProgressCard ? 1 : 0)
            }
        }
        .frame(height: 320)
        .onTapGesture {
            flipCard()
        }
        .padding(.horizontal, 16)
    }
    
    // Flip card animation
    private func flipCard() {
        // Perform flip animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isFlipping = true
            showingProgressCard.toggle()
        }
        
        // Save preference
        lastViewedCard = showingProgressCard ? "progress" : "streak"
        
        // Reset flipping state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isFlipping = false
        }
    }
    
    // Start auto-rotation timer (10 seconds first time, then 15 seconds)
    private func startAutoRotation() {
        stopAutoRotation() // Clear any existing timer
        
        print("🔄 [Dashboard] Starting auto-rotation. isFirstFlip: \(isFirstFlip)")
        
        if isFirstFlip {
            // First flip after 10 seconds
            print("⏱️ [Dashboard] Scheduling first flip in 10 seconds...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                print("🔄 [Dashboard] Executing first flip!")
                
                // Perform first auto-flip
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isFlipping = true
                    self.showingProgressCard.toggle()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.isFlipping = false
                }
                
                self.isFirstFlip = false
                print("✅ [Dashboard] First flip complete. Starting regular rotation...")
                
                // Start regular 15-second timer
                self.startRegularRotation()
            }
        } else {
            // Already did first flip, start regular rotation
            print("⏱️ [Dashboard] First flip already done, starting regular rotation...")
            startRegularRotation()
        }
    }
    
    // Regular rotation every 15 seconds
    private func startRegularRotation() {
        stopAutoRotation() // Clear any existing timer
        
        print("⏱️ [Dashboard] Starting regular 15-second rotation timer...")
        autoRotationTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            print("🔄 [Dashboard] Auto-flip triggered (15s interval)")
            
            // Perform auto-flip
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isFlipping = true
                self.showingProgressCard.toggle()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.isFlipping = false
            }
        }
    }
    
    // Stop auto-rotation timer
    private func stopAutoRotation() {
        autoRotationTimer?.invalidate()
        autoRotationTimer = nil
    }
    
    // MARK: - Greeting Header
    
    private var greetingHeader: some View {
        HStack {
            // Greeting text
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.title3.bold())
                    .foregroundColor(.appTextPrimary)
                
                Text(userName.isEmpty ? "there" : userName)
                    .font(.title2.bold())
                    .foregroundColor(.appTextPrimary)
            }
            .onAppear {
                print("🔍 [Dashboard] userName from UserDefaults: '\(userName)'")
                print("🔍 [Dashboard] userName isEmpty: \(userName.isEmpty)")
            }
            
            Spacer()
            
            // Profile picture placeholder - Tappable
            Button {
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                showProfileSheet = true
            } label: {
                ZStack {
                    if let profileImage = profileImage {
                        // Show profile picture
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        // Show gradient circle with initial
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(userInitial)
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .onAppear {
                // Load profile image from storage
                if let imageData = profileImageData, let image = UIImage(data: imageData) {
                    profileImage = image
                }
            }
        }
    }
    
    // Time-based greeting
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning,"
        case 12..<17:
            return "Good afternoon,"
        default:
            return "Good evening,"
        }
    }
    
    // User initial for profile picture
    private var userInitial: String {
        if userName.isEmpty {
            return "👤"
        }
        return String(userName.prefix(1).uppercased())
    }

    private func miniTag(text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.15))
            .cornerRadius(6)
    }

    // MARK: - Lightning Emoji Progress Meter
    private func circularProgressView(data: MeterResponse) -> some View {
        VStack(spacing: 2) {
            ZStack {
                // Gray base lightning (always visible)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 85, weight: .bold))
                    .foregroundColor(Color.appProgressTrack)
                
                // Calculate eased progress for better visual representation
                // Uses gentle power curve (0.7) to make fill more visible without over-amplifying
                let normalizedProgress = data.progress / 100.0
                let easedProgress = pow(normalizedProgress, 0.7) * 100.0
                
                // Gradient-filled lightning (masked by eased progress)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 85, weight: .bold))
                    .foregroundStyle(Color.appAccentGradient)
                    .shadow(color: progressGlowColor, radius: 20)
                    .shadow(color: progressGlowColor, radius: 30)
                    .mask(
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(
                                        width: geometry.size.width,
                                        height: geometry.size.height * (easedProgress / 100)
                                    )
                            }
                        }
                    )
                    .animation(.easeInOut(duration: 1.0), value: data.progress)
                
                // Outer glow layers
                ForEach(0..<2, id: \.self) { index in
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 85, weight: .bold))
                        .foregroundStyle(Color.appAccentGradient)
                        .opacity(0.15 * (easedProgress / 100))
                        .blur(radius: 15 + (CGFloat(index) * 10))
                        .mask(
                            GeometryReader { geometry in
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(
                                            width: geometry.size.width,
                                            height: geometry.size.height * (easedProgress / 100)
                                        )
                                }
                            }
                        )
                        .animation(.easeInOut(duration: 1.0), value: data.progress)
                }
            }
            .frame(width: 180, height: 180)
            .scaleEffect(0.85 + (data.progress / 100) * 0.15)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: data.progress)
            
            // Progress percentage and label below
            VStack(spacing: 2) {
                Text("\(Int(data.progress))%")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Rewired")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(-0.5)
            }
        }
    }
    
    // Glow only in dark mode
    private var progressGlowColor: Color {
        colorScheme == .dark ? Color.appAccent.opacity(0.5) : Color.clear
    }

    // MARK: - Streak Calendar
    private var streakCalendarView: some View {
        ZStack {
            // Different gradient for streak card (warmer tones)
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.4, blue: 0.3),   // Red-Orange
                    Color(red: 1.0, green: 0.6, blue: 0.2),   // Orange
                    Color(red: 1.0, green: 0.8, blue: 0.3),   // Yellow-Orange
                    Color(red: 1.0, green: 0.5, blue: 0.6)    // Pink-Orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glassmorphism overlay
            Color.white.opacity(0.15)
            
            // Content
            VStack(spacing: 16) {
                // Streak Counter Header
                HStack(spacing: 12) {
                    Text("🔥")
                        .font(.system(size: 36))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(currentStreak) Day Streak")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        Text("Keep it going!")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Spacer()
                }
                
                // Week Days Header
                HStack(spacing: 0) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Week Days Grid
                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.date) { dayData in
                        dayCircleGradient(dayData: dayData)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Weekly Progress Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Weekly Progress")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.85))
                        
                        Spacer()
                        
                        Text("\(completedDaysCount)/7 days")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 6)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(
                                    width: geometry.size.width * (Double(completedDaysCount) / 7.0),
                                    height: 6
                                )
                                .animation(.easeInOut(duration: 0.5), value: completedDaysCount)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(20)
        }
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
    
    // Individual Day Circle for Gradient Card
    private func dayCircleGradient(dayData: (day: String, date: Int, isCompleted: Bool)) -> some View {
        ZStack {
            Circle()
                .fill(dayData.isCompleted ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle().stroke(
                        Color.white.opacity(dayData.isCompleted ? 0.8 : 0.3),
                        lineWidth: dayData.isCompleted ? 2.5 : 1.5
                    )
                )
            
            if dayData.isCompleted {
                Image(systemName: "bolt.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
            } else {
                Text("\(dayData.date)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(width: 40, height: 40)
    }
    
    // Computed property for current streak
    private var currentStreak: Int {
        meterDataManager.meterData?.streak ?? 0
    }
    
    // Computed property for completed days count
    private var completedDaysCount: Int {
        weekDays.filter { $0.isCompleted }.count
    }
    
    // MARK: - Old Day Circle (kept for reference, can be removed)
    // Individual Day Circle
    private func dayCircle(dayData: (day: String, date: Int, isCompleted: Bool)) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(dayData.isCompleted ? Color.appAccent.opacity(0.12) : Color.clear)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(
                            dayData.isCompleted ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing),
                            lineWidth: dayData.isCompleted ? 2.5 : 1.5
                        )
                    )
                    .shadow(
                        color: dayData.isCompleted ? dayGlowColor : .clear,
                        radius: dayData.isCompleted ? 8 : 0
                    )

                if dayData.isCompleted {
                    completedDayBolt
                } else {
                    Text("\(dayData.date)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }
            }
            .frame(width: 44, height: 44)
            Color.clear.frame(height: 20)
        }
    }
    
    // Day glow only in dark mode
    private var dayGlowColor: Color {
        colorScheme == .dark ? Color.appAccent.opacity(0.4) : Color.clear
    }
    
    // Completed Day Lightning Bolt
    private var completedDayBolt: some View {
        Image(systemName: "bolt.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundColor(.appAccent)
            .shadow(color: boltGlowColor, radius: 6)
            .overlay(
                Circle()
                    .stroke(Color.appAccent.opacity(0.3), lineWidth: 2)
                    .scaleEffect(pulse ? 1.2 : 0.95)
                    .opacity(pulse ? 0.0 : 0.7)
            )
    }
    
    // Bolt glow stronger in dark mode
    private var boltGlowColor: Color {
        colorScheme == .dark ? Color.appAccent.opacity(0.8) : Color.appAccent.opacity(0.3)
    }

    private func generateWeekData() {
        let calendar = Calendar.current
        let today = Date()

        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return }

        weekDays = (0..<7).map { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                return (day: "", date: 0, isCompleted: false)
            }

            let dayNumber = calendar.component(.day, from: date)
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            let isCompleted = calendar.isDate(date, inSameDayAs: today) && meterDataManager.isTodayHackComplete

            return (day: String(dayName.prefix(1)), date: dayNumber, isCompleted: isCompleted)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(MeterDataManager.shared)
}

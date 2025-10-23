import SwiftUI
import AVFoundation

struct DailyHackView: View {
    @StateObject private var viewModel: DailyHackViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showShareSheet = false
    @State private var showChat = false
    @State private var chatFromPage: HackPage = .quote
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isLoadingAudio = false
    
    let autoPlayVoice: Bool
    let preGeneratedAudioUrls: [String]
    @State private var isPlaying = false
    @State private var showVoiceSelector = false
    @State private var selectedVoiceIndex = 0
    
    // OpenAI TTS Voices - 3 Male + 3 Female
    let availableVoices: [(name: String, voiceId: String)] = [
        ("Onyx (Male, Powerful)", "onyx"),
        ("Echo (Male, Deep)", "echo"),
        ("Shimmer (Female, Calm)", "shimmer"),
        ("Nova (Female, Warm)", "nova"),
    ]

    init(autoPlayVoice: Bool = false, preloadedHack: BrainHack? = nil, preGeneratedAudioUrls: [String] = []) {
        self.autoPlayVoice = autoPlayVoice
        self.preGeneratedAudioUrls = preGeneratedAudioUrls
        if let hack = preloadedHack {
            _viewModel = StateObject(wrappedValue: DailyHackViewModel(preloadedHack: hack))
        } else {
            _viewModel = StateObject(wrappedValue: DailyHackViewModel())
        }
        print("🎵 Initialized with \(preGeneratedAudioUrls.count) audio URLs")
    }
    
    var body: some View {
        ZStack {
            if let hack = viewModel.todaysHack {
                TabView(selection: $currentPage) {
                    page1HackQuote(hack: hack).tag(0)
                    page2Science(hack: hack).tag(1)
                    page3Application(hack: hack).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentPage) { oldValue, newValue in
                    print("🔄 Page changed from \(oldValue) to \(newValue)")
                }
                
                // DOTS REMOVED - this VStack was deleted
                
                VStack {
                    HStack {
                        if currentPage > 0 {
                            Button {
                                withAnimation {
                                    currentPage -= 1
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .padding()
                        } else {
                            Color.clear.frame(width: 60, height: 60)
                        }
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    Spacer()
                }
                
                // Voice Controls (only show in Listen mode)
                if autoPlayVoice {
                    voiceControlsBar
                }
                
            } else if let error = viewModel.errorMessage {
                errorView(error: error)
            } else {
                // Loading
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let hack = viewModel.todaysHack {
                ShareSheet(items: [generateShareText(hack: hack)])
            }
        }
        .sheet(isPresented: $showChat) {
            if let hack = viewModel.todaysHack {
                HackChatView(hack: hack, fromPage: chatFromPage)
            }
        }
        .onChange(of: currentPage) { _, newPage in
            if autoPlayVoice {
                audioPlayer?.stop()
                isPlaying = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    readCurrentPage()
                }
            }
        }
        .onAppear {
            print("📱 DailyHackView appeared - autoPlayVoice: \(autoPlayVoice)")
            
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                print("✅ Audio session activated")
            } catch {
                print("❌ Audio session error: \(error)")
            }

            if autoPlayVoice {
                print("🎧 Will auto-play in 0.5s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("▶️ Calling readCurrentPage()")
                    readCurrentPage()
                }
            }
        }
        .onDisappear {
            audioPlayer?.stop()
            audioPlayer = nil
            NotificationCenter.default.post(name: Notification.Name("RefreshDashboard"), object: nil)
        }
    }
    
    // Add this computed property
    private var pageProgress: Double {
        switch currentPage {
        case 0: return 35.0
        case 1: return 70.0
        case 2: return 100.0
        default: return 0.0
        }
    }
    
    // MARK: - Voice Controls Bar
    
    private var voiceControlsBar: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 40) {
                // Voice Selector Button - Re-enabled
                Button {
                    showVoiceSelector = true
                } label: {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                // Play/Pause Button
                Button {
                    if isPlaying {
                        pauseSpeech()
                    } else {
                        if audioPlayer?.isPlaying == false && audioPlayer != nil {
                            continueSpeech()
                        } else {
                            readCurrentPage()
                        }
                    }
                } label: {
                    if isLoadingAudio {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 70, height: 70)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                
                // Replay Button
                Button {
                    replaySpeech()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 120)
        }
        .confirmationDialog("Select Voice", isPresented: $showVoiceSelector, titleVisibility: .visible) {
            ForEach(0..<availableVoices.count, id: \.self) { index in
                Button(availableVoices[index].name) {
                    selectedVoiceIndex = index
                    audioPlayer?.stop()
                    audioPlayer = nil
                    isPlaying = false
                    isLoadingAudio = false
                    
                    // Regenerate with new voice
                    Task {
                        await regenerateWithNewVoice()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Switching voice will regenerate audio")
        }
    }
    
    // MARK: - Voice Reading Functions
    
    private func readCurrentPage() {
        fetchAndPlayAudio()
    }
    
    private func pauseSpeech() {
        audioPlayer?.pause()
        isPlaying = false
    }

    private func continueSpeech() {
        audioPlayer?.play()
        isPlaying = true
    }

    private func replaySpeech() {
        audioPlayer?.stop()
        isPlaying = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            fetchAndPlayAudio()
        }
    }
    
    // MARK: - Audio Functions

    private func fetchAndPlayAudio() {
        guard autoPlayVoice, let hack = viewModel.todaysHack else {
            print("❌ Cannot play: autoPlayVoice=\(autoPlayVoice)")
            return
        }
        
        guard !isLoadingAudio else {
            print("⚠️ Already loading audio")
            return
        }
        
        print("🎵 Audio URLs available: \(preGeneratedAudioUrls.count)")
        print("🎵 Current page: \(currentPage)")
        
        // Check if we have pre-generated audio URL for this page
        if currentPage < preGeneratedAudioUrls.count && !preGeneratedAudioUrls.isEmpty {
            let audioUrl = preGeneratedAudioUrls[currentPage]
            print("🚀 Downloading pre-generated audio from: \(audioUrl)")
            
            isLoadingAudio = true
            audioPlayer?.stop()
            audioPlayer = nil
            
            Task {
                do {
                    let audioData = try await downloadAudio(from: audioUrl)
                    print("✅ Downloaded \(audioData.count) bytes")
                    
                    await MainActor.run {
                        do {
                            audioPlayer = try AVAudioPlayer(data: audioData)
                            audioPlayer?.prepareToPlay()
                            audioPlayer?.play()
                            isPlaying = true
                            isLoadingAudio = false
                            print("✅ Playing pre-generated audio!")
                        } catch {
                            print("❌ Audio player error: \(error)")
                            isLoadingAudio = false
                            isPlaying = false
                        }
                    }
                } catch {
                    print("❌ Download error: \(error)")
                    await MainActor.run {
                        isLoadingAudio = false
                        isPlaying = false
                    }
                }
            }
        } else {
            // FALLBACK: Generate audio on-the-fly
            print("📡 No pre-generated audio - generating on-the-fly")
            
            isLoadingAudio = true
            audioPlayer?.stop()
            audioPlayer = nil
            
            let textToRead: String
            switch currentPage {
            case 0:
                textToRead = "\(hack.quote). This is called: \(hack.hackName)"
            case 1:
                textToRead = "The neuroscience behind this hack: \(hack.neuroscience). \(hack.personalization ?? "")"
            case 2:
                textToRead = "Your action plan: \(hack.explanation). Today's challenge: Apply this hack when you face \(hack.barrier) today."
            default:
                isLoadingAudio = false
                return
            }
            
            let selectedVoice = availableVoices[selectedVoiceIndex].voiceId
            
            Task {
                do {
                    let audioData = try await callTTSFunction(text: textToRead, voice: selectedVoice)
                    
                    await MainActor.run {
                        do {
                            audioPlayer = try AVAudioPlayer(data: audioData)
                            audioPlayer?.prepareToPlay()
                            audioPlayer?.play()
                            isPlaying = true
                            isLoadingAudio = false
                            print("✅ Playing generated audio!")
                        } catch {
                            print("❌ Audio player error: \(error)")
                            isLoadingAudio = false
                            isPlaying = false
                        }
                    }
                } catch {
                    print("❌ TTS API error: \(error)")
                    await MainActor.run {
                        isLoadingAudio = false
                        isPlaying = false
                    }
                }
            }
        }
    }
    
    private func downloadAudio(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
    
    private func regenerateWithNewVoice() async {
        guard let hack = viewModel.todaysHack else { return }
        
        isLoadingAudio = true
        
        let textToRead: String
        switch currentPage {
        case 0:
            textToRead = "\(hack.quote). This is called: \(hack.hackName)"
        case 1:
            textToRead = "The neuroscience behind this hack: \(hack.neuroscience). \(hack.personalization ?? "")"
        case 2:
            textToRead = "Your action plan: \(hack.explanation). Today's challenge: Apply this hack when you face \(hack.barrier) today."
        default:
            isLoadingAudio = false
            return
        }
        
        let selectedVoice = availableVoices[selectedVoiceIndex].voiceId
        
        do {
            let audioData = try await callTTSFunction(text: textToRead, voice: selectedVoice)
            
            await MainActor.run {
                do {
                    audioPlayer = try AVAudioPlayer(data: audioData)
                    audioPlayer?.prepareToPlay()
                    audioPlayer?.play()
                    isPlaying = true
                    isLoadingAudio = false
                } catch {
                    print("❌ Audio player error: \(error)")
                    isLoadingAudio = false
                    isPlaying = false
                }
            }
        } catch {
            print("❌ TTS API error: \(error)")
            await MainActor.run {
                isLoadingAudio = false
                isPlaying = false
            }
        }
    }

    private func callTTSFunction(text: String, voice: String) async throws -> Data {
        let supabaseURL = "https://yykxwlioounydxjikbjs.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5a3h3bGlvb3VueWR4amlrYmpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NzU4NjYsImV4cCI6MjA3NTM1MTg2Nn0.u2U6xApU-ViMe1FO5TtRa31-y76nEgohsF1jJ63rk0Q"
        
        guard let url = URL(string: "\(supabaseURL)/functions/v1/text-to-speech") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["text": text, "voice": voice]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
    
    // MARK: - Page 1: The Hack Quote
    
    private func page1HackQuote(hack: BrainHack) -> some View {
        GeometryReader { geometry in
            ZStack {
                AsyncImage(url: URL(string: ImageService.getTodaysImage())) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    case .failure(_), .empty:
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    @unknown default:
                        Color.black
                    }
                }
                .ignoresSafeArea()
                
                Color.black.opacity(0.3).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topSection(progress: viewModel.todaysProgress ?? 0)
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text("YOUR BRAIN HACK • 1 MIN")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        
                        Text(hack.quote)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: geometry.size.width - 48)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(hack.hackName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: geometry.size.width - 48)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: geometry.size.width)
                    
                    Spacer()
                    
                    bottomButtons(isLastPage: false)
                        .frame(maxWidth: geometry.size.width)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 10 : 30)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Page 2: The Science
    
    private func page2Science(hack: BrainHack) -> some View {
        GeometryReader { geometry in
            ZStack {
                // NEW: Deep blue gradient for neuroscience
                LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.85, blue: 0.35),  // Warm gold/yellow
                                    Color(red: 0.55, green: 0.45, blue: 0.75),  // Mid purple
                                    Color(red: 0.25, green: 0.15, blue: 0.45)   // Deep purple (dashboard color)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topSection(progress: viewModel.todaysProgress ?? 0)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "brain")
                                Text("THE NEUROSCIENCE • 3 MIN")
                                    .font(.caption.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.top, 20)
                            
                            Text("In \(hack.hackName), we target specific brain mechanisms.")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: geometry.size.width - 48)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text(hack.neuroscience)
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: geometry.size.width - 48)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if let personalization = hack.personalization, !personalization.isEmpty {
                                Text(personalization)
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(6)
                                    .padding(.horizontal, 24)
                                    .frame(maxWidth: geometry.size.width - 48)
                                    .padding(.top, 16)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: geometry.size.width)
                        .padding(.bottom, autoPlayVoice ? 180 : 30)
                    }
                    
                    bottomButtons(isLastPage: false)
                        .frame(maxWidth: geometry.size.width)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 10 : 30)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Page 3: How to Apply
    
    private func page3Application(hack: BrainHack) -> some View {
        GeometryReader { geometry in
            ZStack {
                // NEW: Dark teal/cyan gradient for action
                LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.85, blue: 0.35),  // Warm gold/yellow
                                    Color(red: 0.55, green: 0.45, blue: 0.75),  // Mid purple
                                    Color(red: 0.25, green: 0.15, blue: 0.45)   // Deep purple (dashboard color)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                .ignoresSafeArea()
                
                // Keep the rest of page 3 the same
                VStack(spacing: 0) {
                    topSection(progress: viewModel.todaysProgress ?? 0)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "hand.tap.fill")
                                Text("HOW TO APPLY • 2 MIN")
                                    .font(.caption.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.top, 20)
                            
                            Text("Your Action Plan")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: geometry.size.width - 48)
                            
                            Text(hack.explanation)
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: geometry.size.width - 48)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today's Challenge:")
                                    .font(.headline)
                                    .foregroundColor(.yellow)
                                
                                Text("Apply this hack when you face \(hack.barrier) today. Notice how your brain responds differently.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .frame(maxWidth: geometry.size.width - 64)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                        }
                        .frame(maxWidth: geometry.size.width)
                        .padding(.bottom, autoPlayVoice ? 180 : 30)
                    }
                    
                    bottomButtons(isLastPage: true)
                        .frame(maxWidth: geometry.size.width)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 10 : 30)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Top Section
    
    private func topSection(progress: Double) -> some View {
        VStack(spacing: 8) {
            Text("Today's Brain Hack")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Text("Progress today")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(Int(pageProgress))%")
                    .font(.caption.bold())
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 32)
            
            ProgressView(value: pageProgress, total: 100)
                .tint(.yellow)
                .padding(.horizontal, 32)
        }
        .padding(.top, 110)  // More padding to push below nav buttons
        .padding(.bottom, 12)
    }
    // MARK: - Bottom Buttons
    
    private func bottomButtons(isLastPage: Bool) -> some View {
        HStack(spacing: 8) {
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
            }
            
            Button {
                switch currentPage {
                case 0: chatFromPage = .quote
                case 1: chatFromPage = .science
                case 2: chatFromPage = .application
                default: chatFromPage = .quote
                }
                showChat = true
            } label: {
                HStack(spacing: 6) {
                    Text("Chat to learn more")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "message.fill")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
            }
            
            if isLastPage {
                Button {
                    Task {
                        await viewModel.markAsComplete()
                        dismiss()
                    }
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 72, height: 56)
                        .background(Color(red: 0.95, green: 0.85, blue: 0.35))
                        .cornerRadius(14)
                }
            } else {
                Button {
                    withAnimation {
                        currentPage += 1
                    }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 72, height: 56)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(14)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helpers
    
    private func generateShareText(hack: BrainHack) -> String {
        """
        🧠 \(hack.hackName)
        
        "\(hack.quote)"
        
        \(hack.explanation)
        
        Shared from Brain Twin App
        """
    }
    
    // MARK: - Error View
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Text("⚠️")
                .font(.system(size: 48))
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Try Again") {
                Task {
                    await viewModel.loadTodaysHack()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DailyHackView()
}

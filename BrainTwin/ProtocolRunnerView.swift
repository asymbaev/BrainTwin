import SwiftUI

struct ProtocolRunnerView: View {
    @StateObject private var viewModel = ProtocolRunnerViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if let proto = viewModel.currentProtocol {
                if viewModel.isCompleted {
                    completionView(proto: proto)
                } else {
                    runnerView(proto: proto)
                }
            } else if let error = viewModel.errorMessage {
                errorView(error: error)
            }
        }
        .navigationTitle("Today's Protocol")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProtocol()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Generating your protocol...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Runner View
    
    private func runnerView(proto: Protocol) -> some View {
        VStack(spacing: 0) {
            headerView(proto: proto)
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    progressIndicator(stepCount: proto.steps.count)
                    
                    if let step = viewModel.currentStep {
                        stepView(step: step, stepNumber: viewModel.currentStepIndex + 1, total: proto.steps.count)
                    }
                    
                    controlsView
                }
                .padding()
            }
        }
    }
    
    private func headerView(proto: Protocol) -> some View {
        VStack(spacing: 12) {
            Text(proto.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            Text(proto.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func progressIndicator(stepCount: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index <= viewModel.currentStepIndex ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private func stepView(step: ProtocolStep, stepNumber: Int, total: Int) -> some View {
        VStack(spacing: 16) {
            Text("Step \(stepNumber) of \(total)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(step.instruction)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            timerCircle
        }
    }
    
    private var timerCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
            
            Circle()
                .trim(from: 0, to: viewModel.timerProgress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: viewModel.timerProgress)
            
            VStack(spacing: 4) {
                Text("\(viewModel.timeRemaining)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                
                Text("seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 200, height: 200)
        .padding()
    }
    
    private var controlsView: some View {
        HStack(spacing: 20) {
            Button {
                viewModel.toggleTimer()
            } label: {
                Image(systemName: viewModel.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
            }
            
            if viewModel.canSkip {
                Button {
                    viewModel.skipStep()
                } label: {
                    Image(systemName: "forward.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Completion View
    
    private func completionView(proto: Protocol) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("🎉")
                .font(.system(size: 80))
            
            Text("Protocol Complete!")
                .font(.title.bold())
            
            Text("You just strengthened your neural pathways!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let science = proto.neuroscienceExplanation {
                scienceCard(text: science)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding()
        }
    }
    
    private func scienceCard(text: String) -> some View {
        VStack(spacing: 8) {
            Text("🧠 The Science")
                .font(.headline)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding(.horizontal)
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
                    await viewModel.loadProtocol()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    NavigationStack {
        ProtocolRunnerView()
    }
}

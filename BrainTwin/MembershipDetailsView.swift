import SwiftUI

struct MembershipDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var currentPlan: PremiumPlan
    @State private var animateCard = false
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.15, green: 0.1, blue: 0.25),
                    Color(red: 0.08, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating particles effect
            GeometryReader { geometry in
                ForEach(0..<8) { i in
                    Circle()
                        .fill(Color.yellow.opacity(0.05))
                        .frame(width: CGFloat.random(in: 20...60))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 10)
                }
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Custom Header
                    ZStack {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        
                        Text("Membership")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                    
                    // Premium Status Card - Glassmorphism
                    VStack(spacing: 20) {
                        // Crown with glow
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.yellow.opacity(0.3), Color.clear],
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 50
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .yellow.opacity(0.5), radius: 10)
                        }
                        .scaleEffect(animateCard ? 1.0 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateCard)
                        
                        VStack(spacing: 8) {
                            Text("Premium Member")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Text("Active")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    
                    // Current Plan Section
                    VStack(spacing: 20) {
                        HStack {
                            Text("Current Plan")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        // Plan Card
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(currentPlan.rawValue)
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                
                                if let savings = currentPlan.savings {
                                    Text(savings)
                                        .font(.caption.bold())
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.yellow)
                                        .cornerRadius(8)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(currentPlan.price)
                                    .font(.system(size: 36, weight: .heavy))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.yellow, Color.orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text(currentPlan.billingCycle)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // Renewal Info
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white.opacity(0.6))
                            Text("Next billing: December 22, 2025")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    
                    // Premium Benefits
                    VStack(spacing: 20) {
                        HStack {
                            Text("What's Included")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        VStack(spacing: 12) {
                            ModernBenefitRow(
                                icon: "brain.head.profile",
                                text: "Daily personalized brain hacks",
                                gradient: [Color.purple, Color.pink]
                            )
                            
                            ModernBenefitRow(
                                icon: "sparkles",
                                text: "AI-powered insights & analytics",
                                gradient: [Color.blue, Color.cyan]
                            )
                            
                            ModernBenefitRow(
                                icon: "chart.line.uptrend.xyaxis",
                                text: "Advanced progress tracking",
                                gradient: [Color.green, Color.mint]
                            )
                            
                            ModernBenefitRow(
                                icon: "headphones",
                                text: "Premium audio narration",
                                gradient: [Color.orange, Color.yellow]
                            )
                            
                            ModernBenefitRow(
                                icon: "message.fill",
                                text: "Unlimited AI chat sessions",
                                gradient: [Color.indigo, Color.purple]
                            )
                            
                            ModernBenefitRow(
                                icon: "bolt.fill",
                                text: "Priority support & updates",
                                gradient: [Color.yellow, Color.orange]
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    
                    // Stats Section
                    HStack(spacing: 16) {
                        StatCard(title: "Days Active", value: "47", icon: "calendar")
                        StatCard(title: "Hacks Done", value: "32", icon: "checkmark.circle")
                        StatCard(title: "Streak", value: "7", icon: "flame.fill")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    
                    Spacer().frame(height: 60)
                }
            }
        }
        .onAppear {
            animateCard = true
        }
    }
}

// Modern Benefit Row with gradient icons
struct ModernBenefitRow: View {
    let icon: String
    let text: String
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
                .frame(width: 24, height: 24)
                .background(Color.green.opacity(0.2))
                .clipShape(Circle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.yellow)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }
}

#Preview {
    MembershipDetailsView(currentPlan: .constant(.monthly))
}

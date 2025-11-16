//
//  SignInView.swift
//  BrainTwin
//
//  Created by Dastan Asymbaev on 11/16/25.
//


import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    let onSignedIn: () -> Void   // called when auth succeeds
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoadingApple = false
    @State private var isLoadingEmail = false
    @State private var errorText: String?
    
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
    
    var body: some View {
        ZStack {
            // SAME BACKGROUND AS BEFORE
            Color.appBackground.ignoresSafeArea()
            
            if colorScheme == .dark {
                RadialGradient(
                    colors: [
                        Color(white: 0.04),
                        .black
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
            
            AdaptiveStarfieldView()
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // MARK: - HEADER (more viral, neuroscience-first)
                VStack(spacing: 10) {
                    Text("Reclaim your mind.")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Neurowire is daily brain rewiring, built on real neuroscience.")
                        .font(.callout)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 64)
                .padding(.horizontal, 32)
                
                // MARK: - GLASS CARD
                VStack(spacing: 18) {
                    
                    Text("Enter the lab")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // APPLE BUTTON
                    SignInWithAppleButton(
                        .continue,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleAppleCompletion
                    )
                    .signInWithAppleButtonStyle(
                        colorScheme == .dark ? .white : .black
                    )
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        Group {
                            if isLoadingApple {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.black.opacity(0.12))
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                }
                            }
                        }
                    )
                    
                    // OR SEPARATOR
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.appCardBorder.opacity(0.7))
                            .frame(height: 1)
                        Text("or brain-hack with email")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.appTextSecondary)
                        Rectangle()
                            .fill(Color.appCardBorder.opacity(0.7))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 2)
                    
                    // EMAIL / PASSWORD STACK
                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.appCardBackground.opacity(0.9))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.appCardBorder.opacity(0.7), lineWidth: 0.7)
                            )
                            .foregroundColor(.appTextPrimary)
                        
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.appCardBackground.opacity(0.9))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.appCardBorder.opacity(0.7), lineWidth: 0.7)
                            )
                            .foregroundColor(.appTextPrimary)
                        
                        Button {
                            Task { await handleEmailSignIn() }
                        } label: {
                            HStack {
                                if isLoadingEmail {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(
                                                tint: colorScheme == .dark ? .black : .white
                                            )
                                        )
                                } else {
                                    Text("Start rewiring with Email")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OnboardingButtonStyle())
                        .disabled(isLoadingEmail || email.isEmpty || password.isEmpty)
                        .opacity((isLoadingEmail || email.isEmpty || password.isEmpty) ? 0.55 : 1)
                        
                        Text("No account yet? We’ll spin up your BrainTwin profile from this email.")
                            .font(.caption2)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                }
                .padding(20)
                .frame(maxWidth: 420) // keeps card nice on big devices
                .background(
                    // Glass / translucent instead of big white slab
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.appCardBorder.opacity(0.35), lineWidth: 0.7)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 18)
                )
                .padding(.horizontal, 24)
                
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                
                Text("By continuing, you agree to BrainTwin’s Terms & Privacy.")
                    .font(.caption2)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
    
    // MARK: - Apple completion handler
    
    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            print("❌ Apple sign in failed: \(error)")
            errorText = "Sign in with Apple failed. Please try again."
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorText = "Invalid Apple credential."
                return
            }
            
            Task {
                await signInToSupabaseWithApple(credential: credential)
            }
        }
    }
    
    private func signInToSupabaseWithApple(
        credential: ASAuthorizationAppleIDCredential
    ) async {
        await MainActor.run {
            isLoadingApple = true
            errorText = nil
        }

        do {
            try await supabase.signInWithApple(credential: credential, nonce: nil)

            await MainActor.run {
                isLoadingApple = false
                errorText = nil
                onSignedIn()
            }
        } catch {
            print("❌ Supabase Apple sign in error: \(error)")
            await MainActor.run {
                isLoadingApple = false
                errorText = "Could not complete sign in with Apple."
            }
        }
    }

    // MARK: - Email handler
    
    private func handleEmailSignIn() async {
        await MainActor.run {
            isLoadingEmail = true
            errorText = nil
        }
        
        do {
            try await supabase.signInOrSignUpWithEmail(email: email, password: password)
            
            await MainActor.run {
                isLoadingEmail = false
                errorText = nil
                onSignedIn()
            }
        } catch {
            print("❌ Email auth error: \(error)")
            await MainActor.run {
                isLoadingEmail = false
                errorText = error.localizedDescription
            }
        }
    }
}

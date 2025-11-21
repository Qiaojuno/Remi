import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct LoginView: View {
    let onAuthenticationSuccess: () -> Void

    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.container) private var container
    @State private var isSigningIn = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // Logo - Poppins Medium with increased negative tracking
                Text("Remi")
                    .font(.custom("Poppins-Medium", size: 73.93))
                    .tracking(-3.0)
                    .foregroundColor(.black)
                    .padding(.top, 80)
                
                // Much smaller spacing between logo and mascot
                
                // Face Plus Image - 171W x 257H
                Image("FacePlus")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 171, height: 257)
                
                // Subtitle - Dark Grey with reduced spacing
                Text("Make sure your loved one never misses another reminder")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "7A7A7A"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Much smaller spacing - bring buttons closer to middle
                VStack(spacing: 0) {
                    Color.clear.frame(height: 30)
                }
                
                // Sign In Buttons - Closer to middle
                VStack(spacing: 12) {
                    // Apple Sign In Button - Pill Shape
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 47)
                    .cornerRadius(23.5)
                    
                    // Google Sign In Button - Pill Shape with GoogleIcon
                    Button(action: {
                        handleGoogleSignIn()
                    }) {
                        HStack {
                            Image("GoogleIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            Text("Sign in with Google")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 47)
                        .background(Color.white)
                        .cornerRadius(23.5)
                    }
                    .disabled(isSigningIn)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
                
            }
            .padding(.horizontal, geometry.size.width * 0.04)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Color(hex: "f9f9f9")

                    VStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color(hex: "B3B3B3").opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                    }
                }
                .ignoresSafeArea(.all)
            )
        }
        .alert("Sign In Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Authentication Methods
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard !isSigningIn else { return }
        isSigningIn = true
        
        switch result {
        case .success(let authorization):
            _Concurrency.Task {
                await processAppleSignIn(authorization)
            }
        case .failure(let error):
            _Concurrency.Task { @MainActor in
                showError("Apple Sign In failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func processAppleSignIn(_ authorization: ASAuthorization) async {
        do {
            let authService = container.resolve(AuthenticationServiceProtocol.self)

            // Use the high-level signInWithApple method (handles nonce internally)
            let result = try await authService.signInWithApple()

            await MainActor.run {
                isSigningIn = false

                // Trigger navigation to dashboard via callback
                onAuthenticationSuccess()
            }
        } catch {
            await MainActor.run {
                showError("Apple Sign In failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleGoogleSignIn() {
        guard !isSigningIn else { return }
        isSigningIn = true
        
        _Concurrency.Task {
            await processGoogleSignIn()
        }
    }
    
    private func processGoogleSignIn() async {
        do {
            let authService = container.resolve(AuthenticationServiceProtocol.self)
            let result = try await authService.signInWithGoogle()

            await MainActor.run {
                isSigningIn = false

                // Trigger navigation to dashboard via callback
                onAuthenticationSuccess()
            }
        } catch {
            await MainActor.run {
                showError("Google Sign In failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods t

    private func showError(_ message: String) {
        isSigningIn = false
        errorMessage = message
        showingError = true
    }
}


// MARK: - Preview
#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        let container = Container.shared
        LoginView(onAuthenticationSuccess: {})
            .environmentObject(OnboardingViewModel(
                authService: container.resolve(AuthenticationServiceProtocol.self),
                databaseService: container.resolve(DatabaseServiceProtocol.self)
            ))
            .inject(container: container)
            .previewDisplayName("Login View")
    }
}
#endif

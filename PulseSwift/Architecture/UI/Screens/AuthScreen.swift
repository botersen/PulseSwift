import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

// MARK: - Premium Authentication Screen (Your Polished Design + Clean Architecture)
struct AuthScreen: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @State private var isSignUp = true
    @State private var showPassword = false
    @State private var usernameError: String?
    @State private var isCheckingUsername = false
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) { // Reduced spacing from 32 to 24
                    Spacer(minLength: 8) // Reduced from 14
                    Spacer(minLength: 8) // Reduced from 16
                    // Welcome text with asymmetrical layout aligned with form
                    VStack(spacing: 4) { // Reduced from 8
                        HStack {
                            Text("Welcome.")
                                .font(.custom("Special Gothic Expanded One", size: 32))
                                .foregroundColor(.white)
                            Spacer()
                    }
                        .padding(.horizontal, 32)
                        
                        HStack {
                            Spacer()
                            Text(isSignUp ? "Let's get you" : "Welcome")
                                .font(.custom("Special Gothic Expanded One", size: 24)) // Increased from 20 to 24
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                }
                        .padding(.horizontal, 32)
                        
                        HStack {
                            Spacer()
                            Text(isSignUp ? "started." : "back.")
                                .font(.custom("Special Gothic Expanded One", size: 24)) // Increased from 20 to 24
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, 32)
            }
            
                    // Form fields section - moved much closer to OR line
                    VStack(spacing: 12) { // Reduced spacing from 16 to 12
                        // Username or Email field (for sign in mode)
                        if !isSignUp {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("username or email:")
                                    .font(.custom("DM Mono", size: 19))
                                    .foregroundColor(.white)
                                
                                TextField("username or email", text: $authViewModel.email)
                                    .font(.custom("DM Mono", size: 19))
                                    .foregroundColor(.white)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
            }
                        }
                        
                        // Username field (for sign up mode)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 4) { // Reduced spacing from 6 to 4
                                Text("choose a username:")
                                    .font(.custom("DM Mono", size: 19))
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("username", text: $authViewModel.username)
                                        .font(.custom("DM Mono", size: 19))
                                        .foregroundColor(.white)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.white.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(usernameError != nil ? Color.red : Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .onChange(of: authViewModel.username) { _, newValue in
                                            // Real-time username validation
                                            validateUsername(newValue)
                                        }
                                    
                                    if let error = usernameError {
                                        Text(error)
                                            .font(.custom("DM Mono", size: 14))
                                            .foregroundColor(.red)
            }
        }
    }
    
                            // Email field for sign up
                            VStack(alignment: .leading, spacing: 4) {
                                Text("email (optional):")
                                    .font(.custom("DM Mono", size: 19))
                .foregroundColor(.white)
            
                                TextField("email", text: $authViewModel.email)
                                    .font(.custom("DM Mono", size: 19))
                                    .foregroundColor(.white)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                            }
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("password:")
                                .font(.custom("DM Mono", size: 19))
                                .foregroundColor(.white)
                            
                            HStack {
                                if showPassword {
                                    TextField("password", text: $authViewModel.password)
                                        .font(.custom("DM Mono", size: 19))
                                        .foregroundColor(.white)
                                } else {
                                    SecureField("password", text: $authViewModel.password)
                                        .font(.custom("DM Mono", size: 19))
                                        .foregroundColor(.white)
                                }
                                
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.system(size: 16))
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Continue button with premium styling
                    Button {
                        if isSignUp {
                            authViewModel.signUp()
                        } else {
                            authViewModel.signInWithCredentials()
                        }
                    } label: {
                        Text(isSignUp ? "create account" : "sign in")
                            .font(.custom("DM Mono", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                    }
                    .disabled(authViewModel.isLoading || (!isSignUp && !authViewModel.isSignInEnabled) || (isSignUp && !authViewModel.isSignUpEnabled))
                    .opacity((authViewModel.isLoading || (!isSignUp && !authViewModel.isSignInEnabled) || (isSignUp && !authViewModel.isSignUpEnabled)) ? 0.6 : 1.0)
                    .padding(.horizontal, 32)
                    
                    // OR divider with premium spacing
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
            
            Text("OR")
                .font(.custom("DM Mono", size: 14))
                            .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
            
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
        }
                    .padding(.horizontal, 32)
                    
                    // Social authentication with premium styling
                    VStack(spacing: 16) {
                        // Apple Sign In
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                switch result {
                                case .success(let authorization):
                                    authViewModel.handleAppleSignInResult(authorization)
                                case .failure(let error):
                                    authViewModel.handleAppleSignInError(error)
                                }
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 56)
                        .cornerRadius(16)
                        .padding(.horizontal, 18)

                        // Google Sign In
                        GoogleSignInButton(
                            scheme: .light,
                            style: .wide,
                            state: .normal,
                            action: {
                                authViewModel.signInWithGoogle()
                            }
                        )
                        .frame(height: 56)
                        .cornerRadius(16)
                        .padding(.horizontal, 18)
                    }
                    .padding(.horizontal, 32)
                    
                    // Toggle sign in/up
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSignUp.toggle()
                        }
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign in" : "Need an account? Sign up")
                            .font(.custom("DM Mono", size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .underline()
        }
                    
                    Spacer()
                    Spacer()
                    Spacer(minLength: 8) // Add a small spacer at the bottom
                }
                .padding(.horizontal, 24)
                .padding(.top, 24) // Reduced from 60 or higher
            }
        }
        .onAppear {
            authViewModel.appFlowViewModel = appFlowViewModel
        }
        .alert("Error", isPresented: .constant(authViewModel.errorMessage != nil)) {
            Button("OK") {
                authViewModel.clearError()
            }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
    }
    
    private func validateUsername(_ username: String) {
        guard !username.isEmpty else {
            usernameError = nil
            return
        }
        
        // Basic validation - industry standard
        if username.count < 3 {
            usernameError = "Username must be at least 3 characters"
        } else if username.count > 20 {
            usernameError = "Username must be less than 20 characters"
        } else if !username.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            usernameError = "Username can only contain letters, numbers, and underscores"
        } else {
            usernameError = nil
        }
    }
}

#Preview {
    AuthScreen()
        .environmentObject(AuthViewModel())
} 
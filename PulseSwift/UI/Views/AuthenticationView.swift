//
//  AuthenticationView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var isSignUp = true
    @State private var showPassword = false
    @State private var usernameError: String?
    @State private var isCheckingUsername = false
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                // Reduced space to move everything up by 40 points
                Spacer(minLength: 14) // Reduced from 54 to 14 (40 point reduction)
                // Reduced additional space for "Let's get you started"
                Spacer(minLength: 16) // Reduced from 36 to 16 (20 more point reduction for total 60 point move up)
                // Welcome text with asymmetrical layout aligned with form
                VStack(spacing: 8) { // Reduced from 16 to 8 to bring lines closer
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
                            
                            TextField("username or email", text: $email)
                                .font(.custom("DM Mono", size: 19))
                                .foregroundColor(.white)
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
                        }
                    }
                    
                    // Username field (for sign up mode)
                    if isSignUp {
                        VStack(alignment: .leading, spacing: 4) { // Reduced spacing from 6 to 4
                            Text("choose a username:")
                                .font(.custom("DM Mono", size: 19))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("username", text: $username)
                                    .font(.custom("DM Mono", size: 19))
                                    .foregroundColor(.white)
                                    .padding(12) // Reduced padding from 16 to 12
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(usernameError != nil ? Color.red.opacity(0.6) : Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .overlay(
                                        HStack {
                                            Spacer()
                                            if isCheckingUsername {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .padding(.trailing, 16)
                                            }
                                        }
                                    )
                                    .onChange(of: username) { _, newValue in
                                        usernameError = nil
                                        if !newValue.isEmpty && newValue.count >= 3 {
                                            checkUsernameAvailability(newValue)
                                        }
                                    }
                                
                                // Username error message
                                if let usernameError = usernameError {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 12))
                                        
                                        Text(usernameError)
                                            .font(.custom("DM Mono", size: 13))
                                            .foregroundColor(.red)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    
                    // Password field with toggle
                    VStack(alignment: .leading, spacing: 4) { // Reduced spacing from 6 to 4
                        Text("password:")
                            .font(.custom("DM Mono", size: 19))
                            .foregroundColor(.white)
                        
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("password", text: $password)
                                } else {
                                    SecureField("password", text: $password)
                                }
                            }
                            .font(.custom("DM Mono", size: 19))
                            .foregroundColor(.white)
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye" : "eye.slash")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(12) // Reduced padding from 16 to 12
                        .onChange(of: password) { _, newPassword in
                            // Filter password to only allow approved characters
                            let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "!@#$%^&*_-."))
                            let filteredPassword = String(newPassword.unicodeScalars.filter { allowedCharacters.contains($0) })
                            
                            if filteredPassword != newPassword {
                                password = filteredPassword
                            }
                            
                            if isSignUp {
                                authManager.validatePasswordRealTime(filteredPassword)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            isSignUp && !password.isEmpty && !authManager.passwordValidation.isValid
                                                ? Color.red.opacity(0.8)
                                                : Color.white.opacity(0.3),
                                            lineWidth: isSignUp && !password.isEmpty && !authManager.passwordValidation.isValid ? 2 : 1
                                        )
                                )
                        )
                        
                        // Password requirements (only for sign up)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 2) {
                                PasswordRequirementView(
                                    text: "Must be 8 characters",
                                    isValid: authManager.passwordValidation.hasMinLength
                                )
                                PasswordRequirementView(
                                    text: "Must include a capital letter",
                                    isValid: authManager.passwordValidation.hasUppercase
                                )
                                PasswordRequirementView(
                                    text: "Must include a number",
                                    isValid: authManager.passwordValidation.hasNumber
                                )
                                PasswordRequirementView(
                                    text: "Must include a character (!@#$%^&*_-.)",
                                    isValid: authManager.passwordValidation.hasSpecialChar
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                // Error message
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.custom("DM Mono", size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }
                
                // Continue arrow button - right above OR line with minimal padding
                HStack {
                    Spacer()
                    Button(action: {
                        if isSignUp {
                            authManager.signUpWithCredentials(username: username, password: password)
                        } else {
                            Task {
                                await authManager.signIn(email: email, password: password)
                            }
                        }
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .disabled(isFormDisabled || authManager.isLoading)
                    .opacity(isFormDisabled ? 0.5 : 1.0)
                }
                .padding(.horizontal, 32)
                .padding(.top, 1)
                .padding(.bottom, 1)
                // OR divider - right below arrow
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                    Text("OR")
                        .font(.custom("DM Mono", size: 17))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 1)
                // Social login buttons section - very compact spacing
                VStack(spacing: 4) { // Reduced spacing from 6 to 4
                    Button(action: {
                        authManager.signInWithApple()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48) // Reduced height from 56 to 48
                        .background(Color.white)
                        .cornerRadius(24) // Adjusted corner radius
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(authManager.isLoading)
                    .padding(.horizontal, 32)
                    Button(action: {
                        authManager.signInWithGoogle()
                    }) {
                        HStack(spacing: 16) {
                            Image("GoogleGLogo")
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48) // Reduced height from 56 to 48
                        .background(Color.white)
                        .cornerRadius(24) // Adjusted corner radius
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(authManager.isLoading)
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 4) // Reduced from 8 to 4
                // Toggle between sign up and sign in
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .font(.custom("Special Gothic Expanded One", size: 17))
                        .foregroundColor(.white.opacity(0.8))
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSignUp.toggle()
                            // Clear form fields when switching
                            username = ""
                            email = ""
                            password = ""
                            authManager.errorMessage = nil
                            // Reset password validation
                            authManager.passwordValidation = PasswordValidation()
                        }
                    }) {
                        Text(isSignUp ? "Sign in" : "Sign up")
                            .font(.custom("Special Gothic Expanded One", size: 17))
                            .foregroundColor(.white)
                            .underline()
                    }
                }
                .padding(.bottom, 8) // Reduced from 16 to 8
                
                // Loading overlay
                if authManager.isLoading {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
            }
        }
        .sheet(isPresented: $authManager.showUsernameCustomization) {
            UsernameCustomizationView(
                suggestedUsername: authManager.suggestedUsername,
                userEmail: authManager.userEmail
            )
            .environmentObject(authManager)
        }
    }
    
    // MARK: - Username Validation
    
    private func checkUsernameAvailability(_ username: String) {
        // Reset error state
        usernameError = nil
        
        // Basic validation first
        if let basicError = validateUsernameFormat(username) {
            usernameError = basicError
            return
        }
        
        // Check for inappropriate content
        if containsInappropriateContent(username) {
            usernameError = "Username contains inappropriate content"
            return
        }
        
        // Check availability (simulate async check)
        isCheckingUsername = true
        
        Task {
            do {
                let isAvailable = try await SupabaseService.shared.isUsernameAvailable(username)
                
                await MainActor.run {
                    isCheckingUsername = false
                    if !isAvailable {
                        usernameError = "Username already taken"
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingUsername = false
                    usernameError = "Unable to check username availability"
                }
            }
        }
    }
    
    private func validateUsernameFormat(_ username: String) -> String? {
        if username.count < 3 {
            return "Username must be at least 3 characters"
        }
        
        if username.count > 20 {
            return "Username must be 20 characters or less"
        }
        
        if !username.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Username can only contain letters, numbers, and underscores"
        }
        
        if username.hasPrefix("_") || username.hasSuffix("_") {
            return "Username cannot start or end with an underscore"
        }
        
        if username.contains("__") {
            return "Username cannot contain consecutive underscores"
        }
        
        return nil
    }
    
    private func containsInappropriateContent(_ username: String) -> Bool {
        let inappropriateWords = [
            "admin", "administrator", "mod", "moderator", "pulse", "pulseapp",
            "system", "support", "help", "api", "www", "mail", "email",
            "fuck", "shit", "damn", "bitch", "ass", "hell", "penis", "vagina",
            "sex", "porn", "xxx", "nude", "naked", "dick", "cock", "pussy",
            "nigger", "faggot", "retard", "gay", "lesbian", "homo", "nazi",
            "hitler", "kill", "die", "death", "suicide", "rape", "murder"
        ]
        
        let lowercaseUsername = username.lowercased()
        return inappropriateWords.contains { inappropriateWord in
            lowercaseUsername.contains(inappropriateWord)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormDisabled: Bool {
        if isSignUp {
            let usernameValid = !username.isEmpty && 
                               usernameError == nil && 
                               !isCheckingUsername
            return !usernameValid || password.count < 8
        } else {
            return email.isEmpty || password.isEmpty
        }
    }
}

// MARK: - Password Requirement View Component
struct PasswordRequirementView: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .red)
                .font(.system(size: 12))
            
            Text(text)
                .font(.custom("DM Mono", size: 13))
                .foregroundColor(isValid ? .green : .red)
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager())
} 
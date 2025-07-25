import SwiftUI
import PhotosUI

struct UsernameCustomizationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var customUsername: String = ""
    @State private var customEmail: String = ""
    @State private var selectedLanguage: String = "English"
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var usernameError: String?
    @State private var isCheckingUsername = false
    
    let suggestedUsername: String
    let userEmail: String
    
    // Check if this is a username/password signup (no email provided)
    private var isUsernamePasswordSignup: Bool {
        userEmail.isEmpty
    }
    
    // Languages supported by OpenAI API for translation
    private let availableLanguages = [
        // Major World Languages
        "English", "Spanish", "French", "German", "Italian", "Portuguese", "Russian",
        "Chinese (Simplified)", "Chinese (Traditional)", "Japanese", "Korean", "Arabic", "Hindi",
        
        // European Languages
        "Dutch", "Swedish", "Norwegian", "Danish", "Finnish", "Polish", "Czech", "Hungarian",
        "Romanian", "Bulgarian", "Croatian", "Serbian", "Slovak", "Slovenian", "Estonian",
        "Latvian", "Lithuanian", "Greek", "Turkish", "Ukrainian", "Belarusian",
        
        // Asian Languages
        "Thai", "Vietnamese", "Indonesian", "Malay", "Tagalog", "Bengali", "Urdu", "Tamil",
        "Telugu", "Marathi", "Gujarati", "Kannada", "Malayalam", "Punjabi", "Nepali",
        "Burmese", "Khmer", "Lao", "Mongolian", "Tibetan",
        
        // Middle Eastern & African Languages
        "Hebrew", "Persian", "Kurdish", "Pashto", "Dari", "Amharic", "Swahili", "Yoruba",
        "Igbo", "Hausa", "Somali", "Afrikaans", "Zulu", "Xhosa",
        
        // South American Languages
        "Catalan", "Galician", "Basque", "Quechua", "Guarani",
        
        // Other Languages
        "Welsh", "Irish", "Scottish Gaelic", "Icelandic", "Maltese", "Luxembourg",
        "Albanian", "Macedonian", "Bosnian", "Montenegrin", "Armenian", "Georgian",
        "Azerbaijani", "Kazakh", "Kyrgyz", "Tajik", "Turkmen", "Uzbek"
    ]
    
    var body: some View {
        ZStack {
            PulseTheme.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Customize Your Profile")
                            .font(.custom("Special Gothic Expanded One", size: 28))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Choose a username and add a profile picture")
                            .font(.custom("DM Mono", size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Profile Picture Section
                    VStack(spacing: 16) {
                        // Profile Picture Preview
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                                
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.white.opacity(0.6))
                                            .font(.system(size: 32))
                                        
                                        Text("Add Photo")
                                            .font(.custom("DM Mono", size: 14))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                        }
                        
                        // Photo Picker
                        PhotosPicker(
                            selection: $selectedImage,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text(profileImage == nil ? "Choose Photo" : "Change Photo")
                                .font(.custom("DM Mono", size: 16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .onChange(of: selectedImage) { _, newValue in
                            loadSelectedImage()
                        }
                    }
                    
                    // Email Section (only for username/password signup)
                    if isUsernamePasswordSignup {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Enter your email:")
                                .font(.custom("DM Mono", size: 19))
                                .foregroundColor(.white)
                            
                            TextField("email@example.com", text: $customEmail)
                                .font(.custom("DM Mono", size: 19))
                                .foregroundColor(.white)
                                .padding(16)
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
                        .padding(.horizontal, 32)
                    }
                    
                    // Username Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose your username:")
                            .font(.custom("DM Mono", size: 19))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("username", text: $customUsername)
                                .font(.custom("DM Mono", size: 19))
                                .foregroundColor(.white)
                                .padding(16)
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
                                .onChange(of: customUsername) { _, newValue in
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
                            
                            // Username validation
                            if !customUsername.isEmpty && usernameError == nil {
                                UsernameValidationView(username: customUsername)
                                    .padding(.top, 4)
                            }
                        }
                        
                        // Add spacing for error messages
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 32)
                    
                    // Language Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose your language:")
                            .font(.custom("DM Mono", size: 19))
                            .foregroundColor(.white)
                        
                        Text("Pulses will be translated to this language")
                            .font(.custom("DM Mono", size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Menu {
                            ForEach(availableLanguages, id: \.self) { language in
                                Button(language) {
                                    selectedLanguage = language
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedLanguage)
                                    .font(.custom("DM Mono", size: 19))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 16))
                            }
                            .padding(16)
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
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.custom("DM Mono", size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 32)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Continue Button
                    VStack(spacing: 16) {
                        GlassButton("CONTINUE") {
                            saveProfile()
                        }
                        .disabled(!canContinue || isLoading)
                        .opacity(!canContinue ? 0.5 : 1.0)
                        .padding(.horizontal, 32)
                        
                        // Skip option
                        Button("Skip for now") {
                            // Use the suggested username and continue
                            finishOnboarding(username: suggestedUsername, profileImage: nil)
                        }
                        .font(.custom("DM Mono", size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 32)
                }
            }
            
            // Loading overlay
            if isLoading {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            customUsername = suggestedUsername
            customEmail = userEmail
        }
    }
    
    // MARK: - Computed Properties
    
    private var canContinue: Bool {
        let usernameValid = !customUsername.isEmpty && 
                           isValidUsername(customUsername) && 
                           usernameError == nil && 
                           !isCheckingUsername
        let emailValid = isUsernamePasswordSignup ? (!customEmail.isEmpty && isValidEmail(customEmail)) : true
        return usernameValid && emailValid
    }
    
    // MARK: - Helper Methods
    
    private func loadSelectedImage() {
        guard let selectedImage = selectedImage else { return }
        
        Task {
            if let data = try? await selectedImage.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.profileImage = uiImage
                }
            }
        }
    }
    
    private func saveProfile() {
        guard canContinue else {
            errorMessage = "Please complete all required fields"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Check username availability
                let isAvailable = try await SupabaseService.shared.isUsernameAvailable(customUsername)
                
                if !isAvailable {
                    await MainActor.run {
                        self.errorMessage = "Username is already taken"
                        self.isLoading = false
                    }
                    return
                }
                
                // Upload profile image if selected
                var profileImageURL: String?
                if let profileImage = profileImage {
                    profileImageURL = try await uploadProfileImage(profileImage)
                }
                
                if isUsernamePasswordSignup {
                    // Complete username/password signup
                    try await authManager.completeUsernamePasswordSetup(
                        finalUsername: customUsername,
                        email: customEmail,
                        preferredLanguage: selectedLanguage,
                        profileImageURL: profileImageURL
                    )
                } else {
                    // Update existing social sign-in user profile
                    try await authManager.updateUserProfile(
                        username: customUsername,
                        preferredLanguage: selectedLanguage,
                        profileImageURL: profileImageURL
                    )
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.finishOnboarding(username: customUsername, profileImage: profileImageURL)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ProfileError.invalidImageData
        }
        
        let fileName = "profile_\(UUID().uuidString).jpg"
        return try await SupabaseService.shared.uploadMedia(
            data: imageData,
            fileName: fileName,
            mimeType: "image/jpeg"
        )
    }
    
    private func finishOnboarding(username: String, profileImage: String?) {
        // Create updated user and complete setup
        let updatedUser = User(
            id: UUID(),
            username: username,
            email: userEmail,
            subscriptionTier: .free,
            profileImageURL: profileImage
        )
        
        authManager.completeProfileSetup(user: updatedUser)
        dismiss()
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
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
}

// MARK: - Username Validation Component

struct UsernameValidationView: View {
    let username: String
    
    private var isValid: Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    private var lengthValid: Bool {
        username.count >= 3 && username.count <= 20
    }
    
    private var charactersValid: Bool {
        username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ValidationRowView(
                text: "3-20 characters",
                isValid: lengthValid
            )
            ValidationRowView(
                text: "Letters, numbers, and underscores only",
                isValid: charactersValid
            )
        }
    }
}

struct ValidationRowView: View {
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

// MARK: - Errors

enum ProfileError: LocalizedError {
    case invalidImageData
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .uploadFailed:
            return "Failed to upload image"
        }
    }
}

#Preview {
    UsernameCustomizationView(
        suggestedUsername: "johnsmith42",
        userEmail: "john@example.com"
    )
    .environmentObject(AuthenticationManager())
} 
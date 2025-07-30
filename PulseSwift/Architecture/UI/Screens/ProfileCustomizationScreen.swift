import SwiftUI

// MARK: - Profile Customization Screen (First-Time Users)
struct ProfileCustomizationScreen: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedProfileImage: UIImage?
    @State private var showingImagePicker = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    HeaderSection()
                    
                    // Profile Image Section
                    ProfileImageSection()
                    
                    // Username Section
                    UsernameSection()
                    
                    // Bio Section
                    BioSection()
                    
                    // Action Buttons
                    ActionButtonsSection()
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedProfileImage)
        }
        .onAppear {
            // Pre-populate username if available from auth
            if let currentUser = authViewModel.currentUser {
                username = currentUser.username
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private func HeaderSection() -> some View {
        VStack(spacing: 16) {
            Text("Welcome to PULSE")
                .font(.custom("Special Gothic Expanded One", size: 32))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Let's customize your profile")
                .font(.custom("DM Mono", size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Profile Image Section
    @ViewBuilder
    private func ProfileImageSection() -> some View {
        VStack(spacing: 16) {
            Button {
                showingImagePicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    if let selectedImage = selectedProfileImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Add Photo")
                                .font(.custom("DM Mono", size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            
            Text("Tap to add profile picture")
                .font(.custom("DM Mono", size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Username Section
    @ViewBuilder
    private func UsernameSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Username")
                .font(.custom("DM Mono", size: 16))
                .foregroundColor(.white)
                .fontWeight(.medium)
            
            TextField("Enter username", text: $username)
                .font(.custom("DM Mono", size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(usernameValid ? Color.green.opacity(0.6) : Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .autocapitalization(.none)
                .autocorrectionDisabled()
            
            if !username.isEmpty && !usernameValid {
                Text("Username must be 3-20 characters (letters, numbers, underscore only)")
                    .font(.custom("DM Mono", size: 12))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }
    
    // MARK: - Bio Section
    @ViewBuilder
    private func BioSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bio (Optional)")
                .font(.custom("DM Mono", size: 16))
                .foregroundColor(.white)
                .fontWeight(.medium)
            
            TextField("Tell us about yourself...", text: $bio, axis: .vertical)
                .font(.custom("DM Mono", size: 16))
                .foregroundColor(.white)
                .lineLimit(3...6)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Action Buttons Section
    @ViewBuilder
    private func ActionButtonsSection() -> some View {
        VStack(spacing: 16) {
            // Continue Button
            Button {
                completeOnboarding()
            } label: {
                Text("Start Pulsing")
                    .font(.custom("DM Mono", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(continueButtonEnabled ? Color.white : Color.white.opacity(0.3))
                    )
            }
            .disabled(!continueButtonEnabled)
            
            // Skip Button
            Button {
                skipCustomization()
            } label: {
                Text("Skip for now")
                    .font(.custom("DM Mono", size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Computed Properties
    private var usernameValid: Bool {
        username.count >= 3 && username.count <= 20 && 
        username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    private var continueButtonEnabled: Bool {
        usernameValid
    }
    
    // MARK: - Actions
    private func completeOnboarding() {
        // Save profile customizations
        saveProfileChanges()
        
        // Complete onboarding flow
        appFlowViewModel.completeOnboarding()
        
        // Show success feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func skipCustomization() {
        // Use default username from auth if available
        if username.isEmpty, let currentUser = authViewModel.currentUser {
            username = currentUser.username
        }
        
        appFlowViewModel.completeOnboarding()
    }
    
    private func saveProfileChanges() {
        // TODO: Implement profile update API call
        print("✅ ProfileCustomization: Saving profile - username: \(username), bio: \(bio)")
        
        // This would typically call:
        // await authUseCases.updateProfile(username: username, bio: bio, profileImage: selectedProfileImage)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            DispatchQueue.main.async {
                if let editedImage = info[.editedImage] as? UIImage {
                    self.parent.selectedImage = editedImage
                } else if let originalImage = info[.originalImage] as? UIImage {
                    self.parent.selectedImage = originalImage
                }
                self.parent.dismiss()
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async {
                self.parent.dismiss()
            }
        }
    }
}

#Preview {
    ProfileCustomizationScreen()
        .environmentObject(AuthViewModel())
        .environmentObject(AppFlowViewModel())
} 
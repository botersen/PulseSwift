import SwiftUI
import AVFoundation

// MARK: - Modern Camera Screen (Instagram-style Minimal UI)
struct ModernCameraScreen: View {
    @ObservedObject private var cameraViewModel = CameraViewModel.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @State private var radiusSelection: PulseRadius?
    @State private var isSelectingRadius = false
    @State private var radiusSliderValue: CGFloat = 0.5
    @State private var showRadiusIndicator = false
    @State private var showTextInput = false
    @State private var messageText = ""
    @State private var isInitialPulse = true // New pulses need radius, returning pulses don't
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Camera preview - only allow text after photo is captured
            if cameraViewModel.isSessionReady {
                CameraPreviewLayer(cameraViewModel: cameraViewModel)
                    .ignoresSafeArea()
                    .onTapGesture(count: 2) {
                        cameraViewModel.switchCamera()
                    }
                    .onTapGesture(count: 1) {
                        // Only show text input if photo has been captured
                        if cameraViewModel.capturedMedia != nil {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showTextInput = true
                                isTextFieldFocused = true
                            }
                        }
                    }
            } else {
                CameraPlaceholderView(cameraViewModel: cameraViewModel)
            }
            
            // Location bar (top left)
            if !isSelectingRadius && cameraViewModel.capturedMedia == nil {
                VStack {
                    HStack {
                        LocationTimeDisplay()
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 45)
                    
                    Spacer()
                }
            }
            
            // Camera controls overlay - hide during radius selection
            if !isSelectingRadius && cameraViewModel.capturedMedia == nil {
                MinimalCameraControls(cameraViewModel: cameraViewModel)
            }
            
            // Captured media preview with radius selection
            if let capturedMedia = cameraViewModel.capturedMedia {
                PostCaptureView(
                    media: capturedMedia,
                    radiusSelection: $radiusSelection,
                    isSelectingRadius: $isSelectingRadius,
                    radiusSliderValue: $radiusSliderValue,
                    showRadiusIndicator: $showRadiusIndicator,
                    onRetake: {
                        cameraViewModel.retakePhoto()
                        radiusSelection = nil
                        showRadiusIndicator = false
                    },
                    onSend: {
                        // Send pulse with selected radius
                        print("Sending pulse with radius: \(radiusSelection?.rawValue ?? "none")")
                        sendPulse()
                    },
                    isInitialPulse: isInitialPulse
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Terminal-style text input
            if showTextInput {
                TerminalTextInput(
                    text: $messageText,
                    isVisible: $showTextInput,
                    isFocused: $isTextFieldFocused
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
            
            // Permission alert
            if cameraViewModel.showPermissionAlert {
                PermissionAlertOverlay(cameraViewModel: cameraViewModel)
            }
            
            // Error overlay
            if let errorMessage = cameraViewModel.errorMessage {
                ErrorOverlay(
                    message: errorMessage,
                    onDismiss: cameraViewModel.clearError
                )
            }
        }
        .onAppear {
            appFlowViewModel.requestAllPermissionsIfNeeded()
            cameraViewModel.onAppear()
        }
        .onDisappear {
            // Keep camera session active
        }
        .onReceive(NotificationCenter.default.publisher(for: .appBecameActive)) { _ in
            cameraViewModel.prepareForForeground()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appWillResignActive)) { _ in
            cameraViewModel.prepareForBackground()
        }
    }
    
    private func sendPulse() {
        guard let radius = radiusSelection else { return }
        
        // Get current location for demo
        let currentLocation = getCurrentLocationName()
        
        // Send pulse through shared app state
        AppState.shared.sendPulse(radius: radius, fromLocation: currentLocation)
        
        // Clean up camera state
        cameraViewModel.retakePhoto()
        radiusSelection = nil
        showRadiusIndicator = false
        
        // After sending initial pulse, subsequent pulses would be returning pulses
        isInitialPulse = false
        
        print("✅ Pulse sent: \(radius.rawValue) from \(currentLocation)")
    }
    
    private func getCurrentLocationName() -> String {
        return RealTimeLocationManager.shared.currentLocationName
    }
}

// MARK: - Pulse Radius Types
enum PulseRadius: String {
    case local = "LOCAL"
    case regional = "REGIONAL"
    case global = "GLOBAL"
    
    var indicator: String {
        switch self {
        case .local: return "L>"
        case .regional: return "R>"
        case .global: return "G>"
        }
    }
    
    static func fromSliderValue(_ value: CGFloat) -> PulseRadius {
        if value >= 0.8 {
            return .global
        } else if value >= 0.35 {
            return .regional
        } else {
            return .local
        }
    }
}

// MARK: - Minimal Camera Controls (Instagram Style)
struct MinimalCameraControls: View {
    let cameraViewModel: CameraViewModel
    
    var body: some View {
        ZStack {
            // Top right controls
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Camera flip button (top right)
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .onTapGesture {
                                print("🔄 BUTTON TAPPED: Camera flip button pressed")
                                cameraViewModel.switchCamera()
                            }
                        
                        // Flash button (under flip button)
                        Image(systemName: cameraViewModel.flashButtonIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .onTapGesture {
                                print("⚡ BUTTON TAPPED: Flash button pressed")
                                cameraViewModel.toggleFlash()
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
            }
            
            // Bottom center capture button
            VStack {
                Spacer()
                
                MinimalCaptureButton(cameraViewModel: cameraViewModel)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Minimal Capture Button
struct MinimalCaptureButton: View {
    let cameraViewModel: CameraViewModel
    @State private var isPressed = false
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 80, height: 80)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .onTapGesture {
                print("🔘 BUTTON TAPPED: Capture button pressed - TAP GESTURE")
                cameraViewModel.capturePhoto()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isPressed = true
                    }
                    .onEnded { _ in
                        isPressed = false
                        print("🔘 BUTTON TAPPED: Capture button pressed - DRAG ENDED")
                        cameraViewModel.capturePhoto()
                    }
            )
    }
}

// MARK: - Post Capture View with Radius Selection
struct PostCaptureView: View {
    let media: CapturedMediaEntity
    @Binding var radiusSelection: PulseRadius?
    @Binding var isSelectingRadius: Bool
    @Binding var radiusSliderValue: CGFloat
    @Binding var showRadiusIndicator: Bool
    let onRetake: () -> Void
    let onSend: () -> Void
    let isInitialPulse: Bool
    
    @State private var dragLocation: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Background image
            Color.black.ignoresSafeArea()
            
            if let uiImage = UIImage(data: media.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }
            
            // Radius selection interface
            if isSelectingRadius {
                RadiusSelectionOverlay(
                    sliderValue: $radiusSliderValue,
                    dragLocation: $dragLocation
                )
            }
            
            // Normal UI when not selecting radius
            if !isSelectingRadius {
                VStack {
                    HStack {
                        // Retake button
                        Button(action: onRetake) {
                            Text("Retake")
                                .font(.custom("DM Mono", size: 16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.6))
                                )
                        }
                        
                        Spacer()
                        
                        // Send button for returning pulses (no radius needed)
                        if !isInitialPulse {
                            Button(action: onSend) {
                                Text("Send")
                                    .font(.custom("DM Mono", size: 16))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(Color.white)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack {
                        Spacer()
                        
                        if showRadiusIndicator, let radius = radiusSelection {
                            // Radius indicator
                            HStack {
                                Spacer()
                                
                                Text(radius.indicator)
                                    .font(.custom("DM Mono", size: 24))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.trailing, 20)
                            }
                        }
                        
                        // SEND PULSE button (only for initial pulses with radius set)
                        if isInitialPulse && radiusSelection != nil && !isSelectingRadius {
                            Button(action: onSend) {
                                Text("SEND PULSE")
                                    .font(.custom("Special Gothic Expanded One", size: 18))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule()
                                            .fill(Color.clear)
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                    )
                            }
                            .padding(.bottom, 80)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Spacer to maintain layout
                            Spacer()
                                .frame(height: 80)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.3) {
            // Only allow radius selection for initial pulses
            if isInitialPulse {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSelectingRadius = true
                    showRadiusIndicator = false
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if isSelectingRadius && isInitialPulse {
                        dragLocation = value.location
                        // Calculate slider value based on vertical position
                        let height = UIScreen.main.bounds.height
                        let normalizedY = 1.0 - (value.location.y / height)
                        radiusSliderValue = max(0, min(1, normalizedY))
                    }
                }
                .onEnded { _ in
                    if isSelectingRadius && isInitialPulse {
                        // Set the radius based on final position
                        radiusSelection = PulseRadius.fromSliderValue(radiusSliderValue)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectingRadius = false
                            showRadiusIndicator = true
                        }
                    }
                }
        )
    }
}

// MARK: - Radius Selection Overlay
struct RadiusSelectionOverlay: View {
    @Binding var sliderValue: CGFloat
    @Binding var dragLocation: CGPoint
    
    var currentRadius: PulseRadius {
        PulseRadius.fromSliderValue(sliderValue)
    }
    
    var body: some View {
        ZStack {
            // Darken background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Vertical slider line on right edge
            HStack {
                Spacer()
                
                ZStack(alignment: .bottom) {
                    // Background line
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 4)
                    
                    // Active portion
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 4, height: UIScreen.main.bounds.height * sliderValue)
                }
                .frame(width: 4)
                .padding(.trailing, 30)
            }
            
            // Radius labels
            VStack {
                // GLOBAL (90% up)
                Text("GLOBAL")
                    .font(.custom("DM Mono", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(currentRadius == .global ? .white : .white.opacity(0.3))
                    .padding(.top, UIScreen.main.bounds.height * 0.1)
                
                Spacer()
                
                // REGIONAL (50% up)
                Text("REGIONAL")
                    .font(.custom("DM Mono", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(currentRadius == .regional ? .white : .white.opacity(0.3))
                
                Spacer()
                
                // LOCAL (20% up)
                Text("LOCAL")
                    .font(.custom("DM Mono", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(currentRadius == .local ? .white : .white.opacity(0.3))
                    .padding(.bottom, UIScreen.main.bounds.height * 0.2)
            }
            
            // Touch indicator
            if dragLocation != .zero {
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .position(x: UIScreen.main.bounds.width - 50, y: dragLocation.y)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Location and Time Display
struct LocationTimeDisplay: View {
    @State private var currentTime = Date()
    @StateObject private var locationManager = RealTimeLocationManager.shared
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Location
            Text(locationManager.currentLocationName)
                .font(.custom("DM Mono", size: 19))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            
            // Time
            Text(formattedTime)
                .font(.custom("DM Mono", size: 19))
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        
        let timeString = formatter.string(from: currentTime)
        let timeZone = TimeZone.current.abbreviation() ?? TimeZone.current.identifier
        
        return "\(timeString) \(timeZone)"
    }
}

// MARK: - Draggable iOS Text Input
struct TerminalTextInput: View {
    @Binding var text: String
    @Binding var isVisible: Bool
    @FocusState.Binding var isFocused: Bool
    
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background tap area to dismiss
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss when tapping anywhere on screen
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                        isFocused = false
                    }
                }
            
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    
                    // Draggable text input container
                    VStack(spacing: 8) {
                        // Drag handle
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 40, height: 4)
                        
                        // Standard iOS text input with floating design
                        TextField("Type your message...", text: $text, axis: .vertical)
                            .focused($isFocused)
                            .font(.system(size: 18, weight: .regular, design: .default))
                            .foregroundColor(.white)
                            .lineLimit(1...10)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .onSubmit {
                                // Return key dismisses keyboard and text box
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isVisible = false
                                    isFocused = false
                                }
                            }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, keyboardHeight + 20)
                    .offset(y: dragOffset)
                    .gesture(
                        // Only allow dragging when keyboard is NOT focused
                        isFocused ? nil : DragGesture()
                            .onChanged { value in
                                // Allow dragging up and down within screen bounds
                                let maxUpward = -(geometry.size.height * 0.5)
                                let maxDownward: CGFloat = 0
                                
                                let newOffset = lastDragOffset + value.translation.height
                                dragOffset = max(maxUpward, min(maxDownward, newOffset))
                            }
                            .onEnded { value in
                                // Save the final position
                                lastDragOffset = dragOffset
                                
                                // Add spring animation for smooth positioning
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    // Snap to positions if close to extremes
                                    if dragOffset < -geometry.size.height * 0.4 {
                                        dragOffset = -geometry.size.height * 0.5
                                        lastDragOffset = dragOffset
                                    } else if dragOffset > -50 {
                                        dragOffset = 0
                                        lastDragOffset = dragOffset
                                    }
                                }
                            }
                    )
                    .onTapGesture {
                        // Prevent background tap from dismissing when tapping text box
                    }
                }
            }
        }
        .onAppear {
            // Reset position when appearing
            dragOffset = 0
            lastDragOffset = 0
        }
    }
    
    private var keyboardHeight: CGFloat {
        // Estimate keyboard height
        return 300
    }
}
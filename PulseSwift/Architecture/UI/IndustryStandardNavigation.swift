import SwiftUI
import SceneKit
import CoreLocation

// MARK: - Industry Standard Navigation Container (Instagram/Snapchat Style)
struct IndustryStandardNavigation: View {
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab = 1 // Start at camera
    
    // Pre-loaded view instances for instant navigation
    @StateObject private var cameraViewModel = CameraViewModel.shared
    @StateObject private var globeViewModel = GlobeViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Settings Screen (Tab 0)
            OptimizedSettingsScreen()
                .tag(0)
                .environmentObject(authViewModel)
                .environmentObject(appFlowViewModel)
            
            // Camera Screen (Tab 1)
            ModernCameraScreen()
                .tag(1)
                .environmentObject(authViewModel)
                .environmentObject(appFlowViewModel)
            
            // Globe Screen (Tab 2)
            OptimizedGlobeView(viewModel: globeViewModel)
                .tag(2)
                .environmentObject(appFlowViewModel)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
        .background(Color.black)
        .onChange(of: selectedTab) { _, newTab in
            handleTabChange(to: newTab)
        }
        .overlay(alignment: .bottom) {
            // Sliding line indicator
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    
                    ZStack(alignment: .leading) {
                        // Background line (divided in 3)
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: geometry.size.width / 3, height: 2)
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: geometry.size.width / 3, height: 2)
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: geometry.size.width / 3, height: 2)
                        }
                        
                        // Active indicator that slides
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width / 3, height: 2)
                            .offset(x: CGFloat(selectedTab) * (geometry.size.width / 3))
                            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
                    }
                    .frame(height: 2)
                    .padding(.bottom, 5)
                }
            }
        }
    }
    
    private func handleTabChange(to tab: Int) {
        // Update app flow state
        switch tab {
        case 0:
            appFlowViewModel.currentFlow = .settings
        case 1:
            appFlowViewModel.currentFlow = .capturePulse
            // Ensure camera is active
            Task { @MainActor in
                cameraViewModel.refreshPreviewConnection()
            }
        case 2:
            appFlowViewModel.currentFlow = .globe
        default:
            break
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Optimized Globe View for Navigation
struct OptimizedGlobeView: View {
    @ObservedObject var viewModel: GlobeViewModel
    @StateObject private var locationManager = RealTimeLocationManager.shared
    @State private var sceneView: SCNView?
    
    var body: some View {
        ZStack {
            // Lightweight wrapper around SceneKit
            SceneKitWrapper(viewModel: viewModel, sceneView: $sceneView, userLocation: locationManager.currentLocation)
                .ignoresSafeArea()
                .allowsHitTesting(false) // Disable interaction for smooth swiping
            
            // World Clock Display - top left
            VStack {
                HStack {
                    WorldClockDisplay()
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 45)
                
                Spacer()
            }
            
            // Live Pulse Location Display - positioned just above navigation line
            VStack {
                Spacer()
                
                LivePulseLocationDisplay(viewModel: viewModel)
                    .padding(.bottom, 20) // Just above the navigation line
            }
        }
        .onAppear {
            viewModel.initializeOnceIfNeeded()
            sceneView?.isPlaying = true
            
            // Request location permission and start tracking
            locationManager.requestLocationPermission()
        }
        .onDisappear {
            sceneView?.isPlaying = false
        }
    }
}

// MARK: - Lightweight SceneKit Wrapper
struct SceneKitWrapper: UIViewRepresentable {
    let viewModel: GlobeViewModel
    @Binding var sceneView: SCNView?
    let userLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> SCNView {
        if let existingView = sceneView {
            return existingView
        }
        
        let newView = createOptimizedSceneView()
        sceneView = newView
        return newView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update user location marker when location changes
        if let location = userLocation {
            print("🌍 SceneKit: Updating location marker for \(location.latitude), \(location.longitude)")
            updateUserLocationMarker(in: uiView.scene, location: location)
        } else {
            print("🌍 SceneKit: No location available for marker")
        }
    }
    
    private func createOptimizedSceneView() -> SCNView {
        let view = SCNView()
        view.scene = createSimpleGlobeScene()
        view.allowsCameraControl = false
        view.backgroundColor = .black
        
        // Maximum performance settings
        view.antialiasingMode = .none
        view.preferredFramesPerSecond = 30
        view.isJitteringEnabled = false
        view.rendersContinuously = false
        
        return view
    }
    
    private func createSimpleGlobeScene() -> SCNScene {
        let scene = SCNScene()
        
        // Simple earth sphere
        let earth = SCNSphere(radius: 1.0)
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "earth_diffuse_map")
        material.lightingModel = .lambert
        earth.materials = [material]
        
        let earthNode = SCNNode(geometry: earth)
        // Y-axis rotation to center on Atlantic (USA/Europe focus), X-axis level
        earthNode.eulerAngles = SCNVector3(0.0, Float.pi + 0.3, 0) // Level X-axis, Atlantic-centered
        scene.rootNode.addChildNode(earthNode)
        
        // User location marker will be added dynamically when location is detected
        
        // Auto rotation
        let rotation = SCNAction.rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: 30)
        earthNode.runAction(SCNAction.repeatForever(rotation))
        
        // Simple lighting
        let light = SCNLight()
        light.type = .ambient
        light.intensity = 500
        let lightNode = SCNNode()
        lightNode.light = light
        scene.rootNode.addChildNode(lightNode)
        
        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 3)
        scene.rootNode.addChildNode(cameraNode)
        
        return scene
    }
    
    private func updateUserLocationMarker(in scene: SCNScene?, location: CLLocationCoordinate2D) {
        guard let scene = scene else { return }
        
        // Remove existing user location marker
        scene.rootNode.childNode(withName: "userLocation", recursively: true)?.removeFromParentNode()
        
        // Convert real coordinates to sphere coordinates
        let lat = Float(location.latitude) * .pi / 180
        let lon = Float(location.longitude) * .pi / 180
        let radius: Float = 1.025 // Slightly above sphere surface
        
        let x = radius * cos(lat) * cos(lon)
        let y = radius * sin(lat)
        let z = -radius * cos(lat) * sin(lon)
        
        // Create user location marker (blinking red dot)
        let locationGeometry = SCNSphere(radius: 0.035) // Larger than stars for visibility
        let locationMaterial = SCNMaterial()
        
        // Bright red for user location
        locationMaterial.diffuse.contents = UIColor.systemRed
        locationMaterial.emission.contents = UIColor.systemRed.withAlphaComponent(0.9)
        locationMaterial.lightingModel = .constant // Always bright
        
        locationGeometry.materials = [locationMaterial]
        
        let locationNode = SCNNode(geometry: locationGeometry)
        locationNode.name = "userLocation"
        locationNode.position = SCNVector3(x, y, z)
        
        // Add blinking animation (fast blink for attention)
        let blinkAnimation = CABasicAnimation(keyPath: "opacity")
        blinkAnimation.fromValue = 1.0
        blinkAnimation.toValue = 0.2
        blinkAnimation.duration = 0.5
        blinkAnimation.autoreverses = true
        blinkAnimation.repeatCount = .infinity
        locationNode.addAnimation(blinkAnimation, forKey: "userBlink")
        
        // Add scale animation too
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.3
        scaleAnimation.duration = 1.0
        scaleAnimation.autoreverses = true
        scaleAnimation.repeatCount = .infinity
        locationNode.addAnimation(scaleAnimation, forKey: "userScale")
        
        scene.rootNode.addChildNode(locationNode)
        print("📍 Added blinking red user location marker at \(location.latitude), \(location.longitude)")
        print("📍 Marker positioned at 3D coordinates: x=\(x), y=\(y), z=\(z)")
        print("📍 Total child nodes in scene: \(scene.rootNode.childNodes.count)")
    }
}

// MARK: - Live Pulse Location Display
struct LivePulseLocationDisplay: View {
    @ObservedObject var viewModel: GlobeViewModel
    @StateObject private var appState = AppState.shared
    @State private var isAnimating = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            Text("LIVE PULSE LOCATION")
                .font(.custom("DM Mono", size: 16))
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .tracking(1.2)
            
            // Location or No Pulse Message
            if let activePulse = appState.activePulse {
                // Show real pulse location
                VStack(spacing: 4) {
                    Text(activePulse.currentLocation)
                        .font(.custom("DM Mono", size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.5), value: activePulse.currentLocation)
                    
                    // Pulse animation indicator
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 6, height: 6)
                                .scaleEffect(isAnimating ? 1.2 : 0.8)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                // No active pulse message
                Text("no pulses active - tap left to send a pulse")
                    .font(.custom("DM Mono", size: 18))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            // Timer just keeps the current location updated for real pulses
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - World Clock Display
struct WorldClockDisplay: View {
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let cityChangeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    // Major world cities with their time zones
    private let worldCities = [
        ("NYC", "America/New_York"),
        ("LA", "America/Los_Angeles"),
        ("London", "Europe/London"),
        ("Paris", "Europe/Paris"),
        ("Berlin", "Europe/Berlin"),
        ("Dubai", "Asia/Dubai"),
        ("Mumbai", "Asia/Kolkata"),
        ("Tokyo", "Asia/Tokyo"),
        ("Sydney", "Australia/Sydney"),
        ("Lagos", "Africa/Lagos"),
        ("Cairo", "Africa/Cairo"),
        ("Rio", "America/Sao_Paulo")
    ]
    
    @State private var selectedCities: [(String, String)] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // World Times
            ForEach(selectedCities.prefix(3), id: \.0) { city, timezone in
                HStack(spacing: 0) {
                    Text(city)
                        .font(.custom("DM Mono", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(" ")
                    
                    Text(timeInTimezone(timezone))
                        .font(.custom("DM Mono", size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onReceive(cityChangeTimer) { _ in
            // Change cities every minute with animation
            withAnimation(.easeInOut(duration: 0.5)) {
                selectRandomCities()
            }
        }
        .onAppear {
            selectRandomCities()
        }
    }
    
    private func selectRandomCities() {
        // Randomly select 3 cities
        selectedCities = worldCities.shuffled().prefix(3).map { $0 }
    }
    
    private func timeInTimezone(_ timeZoneIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        if let timezone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timezone
            return formatter.string(from: currentTime)
        }
        
        return "--:--"
    }
}
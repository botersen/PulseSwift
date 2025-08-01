import SwiftUI
import SceneKit
import CoreLocation

// MARK: - Globe View (SwiftUI Wrapper)
struct GlobeView: View {
    @StateObject private var globeViewModel = GlobeViewModel()
    @State private var selectedStar: GlobeStarEntity?
    @State private var showStarDetails = false
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    
    var body: some View {
        ZStack {
            // SceneKit Globe
            GlobeSceneView(
                viewModel: globeViewModel,
                selectedStar: $selectedStar,
                showStarDetails: $showStarDetails
            )
            .ignoresSafeArea()
            
            // UI Overlays
            VStack {
                // Top Navigation
                HStack {
                    // Back to Camera Button
                    Button(action: {
                        appFlowViewModel.navigateToCamera()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Live Pulse Location Display
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIVE PULSE LOCATION")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1)
                    
                    if globeViewModel.hasActivePulse {
                        Text(globeViewModel.currentPulseLocation)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    } else {
                        Text("No pulses active - tap left to send a pulse")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .padding()
            }
        }
        .sheet(isPresented: $showStarDetails) {
            if let star = selectedStar {
                StarDetailView(star: star)
            }
        }
        .onAppear {
            globeViewModel.startRealtimeUpdates()
            
            // Add test locations for coordinate verification (for demo)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                globeViewModel.addTestPulseLocations()
                globeViewModel.startRealTimeUpdates()
            }
        }
        .onDisappear {
            globeViewModel.stopRealtimeUpdates()
        }
    }
}

// MARK: - SceneKit Scene View
struct GlobeSceneView: UIViewRepresentable {
    let viewModel: GlobeViewModel
    @Binding var selectedStar: GlobeStarEntity?
    @Binding var showStarDetails: Bool
    
    // No texture caching needed - using original diffuse map directly
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = createGlobeScene()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.backgroundColor = UIColor.black
        sceneView.delegate = context.coordinator
        
        // Setup gesture recognizers
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Setup pan gesture to detect user interaction with the globe
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        // Store reference to scene view for rotation control
        context.coordinator.sceneView = sceneView
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        Task { @MainActor in
            context.coordinator.updateStars(viewModel.stars)
            context.coordinator.updateActivePulses(viewModel.activePulses)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createGlobeScene() -> SCNScene {
        let scene = SCNScene()
        
        // Create Earth sphere with accurate geographic mapping
        let earthGeometry = SCNSphere(radius: 1.0)
        let earthMaterial = SCNMaterial()
        
        // Use the original diffuse map with subtle reflective properties
        earthMaterial.diffuse.contents = UIImage(named: "earth_diffuse_map") ?? createSimpleGreyEarthTexture()
        
        print("✅ GlobeView: Using original Earth diffuse map with reflective surface")
        
        // Game-like material properties - subtle and even
        earthMaterial.specular.contents = UIColor(white: 0.15, alpha: 1.0) // Very subtle reflections
        earthMaterial.shininess = 0.2 // Low shine for even appearance
        earthMaterial.lightingModel = .lambert // Simpler lighting for game-like feel
        // No metalness - keep it clean and game-like
        
        // Ensure proper UV mapping for geographic accuracy
        earthMaterial.diffuse.wrapS = .repeat
        earthMaterial.diffuse.wrapT = .clampToBorder
        
        earthGeometry.materials = [earthMaterial]
        
        let earthNode = SCNNode(geometry: earthGeometry)
        earthNode.name = "earth"
        
        // Rotate the Earth to center on US/Europe (Y axis rotation adjustment)
        // Adjust Y rotation to bring US/Europe towards center view
        earthNode.eulerAngles = SCNVector3(0, Float.pi + 0.4, 0) // Y axis adjustment to center on US/Europe
        
        scene.rootNode.addChildNode(earthNode)
        
        // Setup game-like even lighting for mobile visibility
        setupGameLighting(scene: scene)
        
        // Setup camera
        let camera = SCNCamera()
        camera.fieldOfView = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        scene.rootNode.addChildNode(cameraNode)
        
        // Add automatic rotation animation to the Earth
        setupAutoRotation(for: earthNode)
        
        return scene
    }
    
    // MARK: - Auto-Rotation Setup
    private func setupAutoRotation(for earthNode: SCNNode) {
        // Create smooth continuous rotation animation (right to left)
        let rotationAction = SCNAction.rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: 30.0)
        let repeatAction = SCNAction.repeatForever(rotationAction)
        
        // Add the animation with a key so we can pause/resume it
        earthNode.runAction(repeatAction, forKey: "autoRotation")
        
        print("🌍 GlobeView: Auto-rotation enabled (right to left, 30s per revolution)")
    }
    
    // MARK: - Game-Like Even Lighting
    private func setupGameLighting(scene: SCNScene) {
        // Higher ambient light for mobile game visibility
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 400 // Much higher for even visibility
        ambientLight.color = UIColor(white: 0.9, alpha: 1.0)
        
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Softer directional light instead of harsh point light
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 300 // Gentler intensity
        directionalLight.color = UIColor(white: 1.0, alpha: 1.0)
        directionalLight.castsShadow = false // No harsh shadows for game-like feel
        
        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.position = SCNVector3(x: 1, y: 1, z: 1) // Softer angle
        directionalNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode)
        
        print("💡 GlobeView: Game-like even lighting setup complete")
    }
    
    // MARK: - Elevation Glow Effect
    private func createElevationGlowMap() -> UIImage {
        // Load both maps to combine them properly
        guard let normalImage = UIImage(named: "earth_normal_map"),
              let diffuseImage = UIImage(named: "earth_diffuse_map") else {
            print("⚠️ GlobeView: Could not load maps for elevation glow")
            return UIImage() // Return empty image
        }
        
        guard let normalCGImage = normalImage.cgImage,
              let diffuseCGImage = diffuseImage.cgImage else {
            return UIImage()
        }
        
        let width = normalCGImage.width
        let height = normalCGImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // Create pixel data arrays for both images
        var normalPixelData = [UInt8](repeating: 0, count: height * width * 4)
        var diffusePixelData = [UInt8](repeating: 0, count: height * width * 4)
        var outputPixelData = [UInt8](repeating: 0, count: height * width * 4)
        
        let normalContext = CGContext(
            data: &normalPixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        
        let diffuseContext = CGContext(
            data: &diffusePixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        
        let outputContext = CGContext(
            data: &outputPixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        
        normalContext?.draw(normalCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        diffuseContext?.draw(diffuseCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Process pixels to create white glow only on high elevations OF LAND
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = ((width * y) + x) * 4
                
                // Get diffuse pixel (to check if land or ocean)
                let diffuseRed = diffusePixelData[pixelIndex]
                let diffuseGreen = diffusePixelData[pixelIndex + 1]
                let diffuseBlue = diffusePixelData[pixelIndex + 2]
                let diffuseBrightness = (Int(diffuseRed) + Int(diffuseGreen) + Int(diffuseBlue)) / 3
                
                // Get normal pixel (elevation data)
                let normalRed = normalPixelData[pixelIndex]
                let normalGreen = normalPixelData[pixelIndex + 1]
                let normalBlue = normalPixelData[pixelIndex + 2]
                let normalBrightness = (Int(normalRed) + Int(normalGreen) + Int(normalBlue)) / 3
                
                // Only apply glow to LAND areas (grey in diffuse) with HIGH elevation
                if diffuseBrightness > 50 && normalBrightness > 160 { // Land + high elevation
                    // Create white glow point
                    let glowIntensity = UInt8(min(255, (normalBrightness - 160) * 2))
                    outputPixelData[pixelIndex] = glowIntensity     // Red
                    outputPixelData[pixelIndex + 1] = glowIntensity // Green
                    outputPixelData[pixelIndex + 2] = glowIntensity // Blue
                    outputPixelData[pixelIndex + 3] = 255          // Alpha
                } else {
                    // No glow - keep oceans and low elevations black
                    outputPixelData[pixelIndex] = 0     // Red
                    outputPixelData[pixelIndex + 1] = 0 // Green
                    outputPixelData[pixelIndex + 2] = 0 // Blue
                    outputPixelData[pixelIndex + 3] = 255 // Alpha
                }
            }
        }
        
        // Create new image from processed pixels
        if let outputCGImage = outputContext?.makeImage() {
            return UIImage(cgImage: outputCGImage)
        }
        
        return UIImage()
    }
    

    
    // Removed texture processing - using original diffuse map directly for clean appearance
    
    private func createOptimizedEmissionTexture() -> UIImage {
        // Create a simple white emission map for mountain peaks (much lighter processing)
        // Use lower resolution for performance
        let size = CGSize(width: 512, height: 256) // Much smaller than original
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Fill with black (no emission by default)
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(rect)
            
            // Add just a few bright white spots for major mountain ranges (hardcoded for performance)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            
            // Himalayas
            let himalayas = CGRect(x: size.width * 0.65, y: size.height * 0.35, width: 8, height: 4)
            context.cgContext.fillEllipse(in: himalayas)
            
            // Rocky Mountains
            let rockies = CGRect(x: size.width * 0.15, y: size.height * 0.3, width: 3, height: 12)
            context.cgContext.fillEllipse(in: rockies)
            
            // Andes
            let andes = CGRect(x: size.width * 0.25, y: size.height * 0.6, width: 2, height: 20)
            context.cgContext.fillEllipse(in: andes)
            
            // Alps
            let alps = CGRect(x: size.width * 0.52, y: size.height * 0.28, width: 3, height: 2)
            context.cgContext.fillEllipse(in: alps)
        }
    }
    
    // MARK: - Accurate Earth Texture Creation (Grey Countries, Black Oceans)
    private func createAccurateEarthTexture() -> UIImage {
        // Load the real earth texture for accurate geography
        guard let earthImage = UIImage(named: "earth_real") else {
            print("⚠️ GlobeView: Could not load earth_real.jpg, using fallback")
            return createFallbackEarthTexture()
        }
        
        // Convert to grey countries on black background while preserving accuracy
        return convertToGreyCountries(earthImage)
    }
    
    private func convertToGreyCountries(_ sourceImage: UIImage) -> UIImage {
        let size = sourceImage.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgContext = context.cgContext
            
            // Draw original image
            sourceImage.draw(in: rect)
            
            // Create overlay for country/ocean detection
            cgContext.setBlendMode(.multiply)
            
            // Process each pixel to convert to grey countries/black oceans
            guard let inputCGImage = sourceImage.cgImage else { return }
            let width = inputCGImage.width
            let height = inputCGImage.height
            
            // Create pixel buffer
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitsPerComponent = 8
            
            var pixelData = [UInt8](repeating: 0, count: height * width * 4)
            
            let bitmapContext = CGContext(
                data: &pixelData,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
            
            bitmapContext?.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // Convert pixels: land = grey, water = black
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = ((width * y) + x) * 4
                    
                    let red = pixelData[pixelIndex]
                    let green = pixelData[pixelIndex + 1]
                    let blue = pixelData[pixelIndex + 2]
                    
                    // Calculate brightness to detect land vs water
                    let brightness = (Int(red) + Int(green) + Int(blue)) / 3
                    
                    if brightness > 50 { // Land (bright pixels)
                        // Convert to grey
                        let greyValue: UInt8 = 120 // Medium grey for countries
                        pixelData[pixelIndex] = greyValue     // Red
                        pixelData[pixelIndex + 1] = greyValue // Green
                        pixelData[pixelIndex + 2] = greyValue // Blue
                    } else { // Water (dark pixels)
                        // Convert to black
                        pixelData[pixelIndex] = 0     // Red
                        pixelData[pixelIndex + 1] = 0 // Green
                        pixelData[pixelIndex + 2] = 0 // Blue
                    }
                }
            }
            
            // Create new image from processed pixels
            if let outputCGImage = bitmapContext?.makeImage() {
                let processedImage = UIImage(cgImage: outputCGImage)
                processedImage.draw(in: rect)
            }
        }
    }
    
    private func createSimpleGreyEarthTexture() -> UIImage {
        // Simple greyscale conversion of existing earth texture
        guard let earthImage = UIImage(named: "earth_texture_4k") else {
            return createFallbackEarthTexture()
        }
        
        // Convert to greyscale
        guard let cgImage = earthImage.cgImage else {
            return createFallbackEarthTexture()
        }
        
        let size = earthImage.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Draw original image in greyscale
            context.cgContext.setBlendMode(.normal)
            context.cgContext.draw(cgImage, in: rect)
            
            // Convert to greyscale using saturation filter
            context.cgContext.setBlendMode(.saturation)
            context.cgContext.setFillColor(UIColor.gray.cgColor)
            context.cgContext.fill(rect)
        }
    }
    
    private func createFallbackEarthTexture() -> UIImage {
        // Simplified fallback with basic continent shapes
        let size = CGSize(width: 1024, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgContext = context.cgContext
            
            // Black ocean base
            cgContext.setFillColor(UIColor.black.cgColor)
            cgContext.fill(rect)
            
            // Grey continents - basic shapes for fallback
            let greyColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0).cgColor
            cgContext.setFillColor(greyColor)
            
            // Basic continent shapes for fallback - just simple rectangles
            let northAmerica = CGRect(x: size.width * 0.05, y: size.height * 0.15, 
                                    width: size.width * 0.25, height: size.height * 0.4)
            let southAmerica = CGRect(x: size.width * 0.20, y: size.height * 0.55, 
                                    width: size.width * 0.15, height: size.height * 0.35)
            let europe = CGRect(x: size.width * 0.45, y: size.height * 0.15, 
                              width: size.width * 0.15, height: size.height * 0.25)
            let africa = CGRect(x: size.width * 0.48, y: size.height * 0.35, 
                              width: size.width * 0.18, height: size.height * 0.35)
            let asia = CGRect(x: size.width * 0.60, y: size.height * 0.15, 
                            width: size.width * 0.30, height: size.height * 0.35)
            let australia = CGRect(x: size.width * 0.75, y: size.height * 0.70, 
                                 width: size.width * 0.15, height: size.height * 0.15)
            
            cgContext.fill(northAmerica)
            cgContext.fill(southAmerica)
            cgContext.fill(europe)
            cgContext.fill(africa)
            cgContext.fill(asia)
            cgContext.fill(australia)
        }
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: GlobeSceneView
        private var starNodes: [UUID: SCNNode] = [:]
        private var pulseLineNodes: [UUID: SCNNode] = [:]
        
        // Auto-rotation control
        weak var sceneView: SCNView?
        private var autoRotationTimer: Timer?
        
        init(_ parent: GlobeSceneView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let sceneView = gesture.view as? SCNView else { return }
        let _ = gesture.location(in: sceneView)
            
            Task { @MainActor in
            // Handle star selection logic here
        }
    }
    
    @MainActor @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Pause auto-rotation during user interaction
        if gesture.state == .began {
            parent.viewModel.isAutoRotating = false
        } else if gesture.state == .ended {
            parent.viewModel.isAutoRotating = true
        }
        }
        
        @MainActor func updateStars(_ stars: [GlobeStarEntity]) {
            guard let scene = parent.viewModel.sceneView?.scene else { return }
            
        // Remove old star nodes
            let currentStarIds = Set(stars.map { $0.id })
        let starsToRemove = starNodes.filter { !currentStarIds.contains($0.key) }
            
        for (_, node) in starsToRemove {
                node.removeFromParentNode()
            }
            starNodes = starNodes.filter { currentStarIds.contains($0.key) }
            
        // Add or update star nodes
            for star in stars {
            if starNodes[star.id] == nil {
                    let starNode = createStarNode(for: star)
                    starNodes[star.id] = starNode
                    scene.rootNode.addChildNode(starNode)
                }
            }
        }
        
        @MainActor func updateActivePulses(_ pulses: [ActivePulseConnectionEntity]) {
            guard let scene = parent.viewModel.sceneView?.scene else { return }
            
            // Remove old pulse lines
            let currentPulseIds = Set(pulses.map { $0.id })
            let linesToRemove = pulseLineNodes.filter { !currentPulseIds.contains($0.key) }
            
            for (_, node) in linesToRemove {
                node.removeFromParentNode()
            }
            pulseLineNodes = pulseLineNodes.filter { currentPulseIds.contains($0.key) }
            
            // Add or update pulse lines
            for pulse in pulses where pulse.isActive {
                if pulseLineNodes[pulse.id] == nil {
                    let lineNode = createPulseLineNode(for: pulse)
                    pulseLineNodes[pulse.id] = lineNode
                    scene.rootNode.addChildNode(lineNode)
                }
            }
        }
        
        private func createStarNode(for star: GlobeStarEntity) -> SCNNode {
            // Create star geometry
        let starGeometry = SCNSphere(radius: CGFloat(star.size * 0.02))
            let starMaterial = SCNMaterial()
            
            let color = star.color.rgba
            starMaterial.emission.contents = UIColor(
                red: CGFloat(color.red),
                green: CGFloat(color.green), 
                blue: CGFloat(color.blue),
                alpha: CGFloat(color.alpha * star.glowIntensity)
            )
            starMaterial.diffuse.contents = UIColor.clear
            starGeometry.materials = [starMaterial]
            
            let starNode = SCNNode(geometry: starGeometry)
            starNode.name = star.id.uuidString
            
            // Position on sphere surface
            let coords = star.sphereCoordinates
        starNode.position = SCNVector3(coords.x * 1.01, coords.y * 1.01, coords.z * 1.01)
            
            // Add pulsing animation
            let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
            pulseAnimation.fromValue = 1.0
            pulseAnimation.toValue = 1.3
            pulseAnimation.duration = 2.0
            pulseAnimation.autoreverses = true
            pulseAnimation.repeatCount = .infinity
            starNode.addAnimation(pulseAnimation, forKey: "pulse")
            
            return starNode
        }
        
        private func createPulseLineNode(for pulse: ActivePulseConnectionEntity) -> SCNNode {
            // Create line between two locations
            let userCoords = convertToSphereCoordinates(pulse.userLocation)
            let partnerCoords = convertToSphereCoordinates(pulse.partnerLocation)
            
            // Create curved line geometry
            let path = UIBezierPath()
            let userPoint = CGPoint(x: CGFloat(userCoords.x), y: CGFloat(userCoords.y))
            let partnerPoint = CGPoint(x: CGFloat(partnerCoords.x), y: CGFloat(partnerCoords.y))
            
            path.move(to: userPoint)
            path.addQuadCurve(to: partnerPoint, controlPoint: CGPoint(
                x: (userPoint.x + partnerPoint.x) / 2,
                y: max(userPoint.y, partnerPoint.y) + 0.3
            ))
            
            let lineGeometry = SCNShape(path: path, extrusionDepth: 0.005)
            let lineMaterial = SCNMaterial()
            lineMaterial.emission.contents = UIColor.cyan.withAlphaComponent(CGFloat(pulse.pulseLineIntensity))
            lineGeometry.materials = [lineMaterial]
            
            let lineNode = SCNNode(geometry: lineGeometry)
            lineNode.name = "pulse_line_\(pulse.id.uuidString)"
            
            return lineNode
        }
        
    private func convertToSphereCoordinates(_ coordinate: CLLocationCoordinate2D) -> (x: Float, y: Float, z: Float) {
            let earthRadius: Float = 1.0
            
            // Convert degrees to radians
        let lat = Float(coordinate.latitude) * .pi / 180.0
        let lon = Float(coordinate.longitude) * .pi / 180.0
            
        // Spherical to Cartesian coordinate conversion
            let x = earthRadius * cos(lat) * cos(lon)
            let y = earthRadius * sin(lat)
        let z = -earthRadius * cos(lat) * sin(lon)
            
            return (x, y, z)
    }
}

// MARK: - Star Detail View
struct StarDetailView: View {
    let star: GlobeStarEntity
    
    var body: some View {
        VStack(spacing: 16) {
                // Star visualization
                Circle()
                    .fill(Color(
                        red: Double(star.color.rgba.red),
                        green: Double(star.color.rgba.green),
                        blue: Double(star.color.rgba.blue)
                    ))
                    .frame(width: 60, height: 60)
                    .shadow(color: .yellow, radius: 10)
                
                // Pulse details
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(title: "Location", value: "\(star.location.latitude.formatted(.number.precision(.fractionLength(2)))), \(star.location.longitude.formatted(.number.precision(.fractionLength(2))))")
                    
                DetailRow(title: "Pulse Duration", value: formatDuration(star.pulseMatch?.pulseDuration ?? 0))
                
                DetailRow(title: "Photos Exchanged", value: "\(star.pulseMatch?.photoCount ?? 0)")
                
                DetailRow(title: "Date", value: star.pulseMatch?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "User Location")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview
struct GlobeView_Previews: PreviewProvider {
    static var previews: some View {
        GlobeView()
            .preferredColorScheme(.dark)
    }
} 

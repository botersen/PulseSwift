import SwiftUI
import SceneKit
import CoreLocation

// MARK: - Globe View (SwiftUI Wrapper)
struct GlobeView: View {
    @StateObject private var globeViewModel = GlobeViewModel()
    @State private var selectedStar: GlobeStarEntity?
    @State private var showStarDetails = false
    
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
                // Top Controls
                HStack {
                    // Time Range Selector
                    Picker("Time Range", selection: $globeViewModel.timeRange) {
                        Text("24h").tag(GlobeViewStateEntity.TimeRange.last24Hours)
                        Text("Week").tag(GlobeViewStateEntity.TimeRange.lastWeek)
                        Text("Month").tag(GlobeViewStateEntity.TimeRange.lastMonth)
                        Text("All").tag(GlobeViewStateEntity.TimeRange.allTime)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Auto-rotation toggle
                    Button(action: {
                        globeViewModel.toggleAutoRotation()
                    }) {
                        Image(systemName: globeViewModel.isAutoRotating ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom Stats
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Pulses")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(globeViewModel.totalPulseCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Active Now")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(globeViewModel.activePulseCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
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
        
        // Use custom Pulse-branded texture (black oceans, silver countries)
        earthMaterial.diffuse.contents = createHighQualityEarthTexture()
        print("✅ GlobeView: Using custom Pulse-branded Earth texture")
        
        // Enhanced material properties for black ocean/silver countries
        earthMaterial.specular.contents = UIColor.clear // No reflections for clean minimal look
        earthMaterial.shininess = 0.0 // Completely matte for sharp contrast
        earthMaterial.lightingModel = .lambert // Clean lighting for the minimalist aesthetic
        
        // Ensure proper UV mapping for geographic accuracy
        earthMaterial.diffuse.wrapS = .repeat
        earthMaterial.diffuse.wrapT = .clampToBorder
        
        earthGeometry.materials = [earthMaterial]
        
        let earthNode = SCNNode(geometry: earthGeometry)
        earthNode.name = "earth"
        
        // Rotate the Earth to match real-world orientation
        // This ensures coordinate mapping is accurate
        earthNode.eulerAngles = SCNVector3(0, Float.pi, 0) // 180° Y rotation for correct longitude orientation
        
        scene.rootNode.addChildNode(earthNode)
        
        // Setup lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 300
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 800
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.position = SCNVector3(x: 2, y: 2, z: 2)
        scene.rootNode.addChildNode(lightNode)
        
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
    
    // MARK: - High-Quality Earth Texture Creation (Black Water, Silver Countries)
    private func createHighQualityEarthTexture() -> UIImage {
        let size = CGSize(width: 2048, height: 1024) // Higher resolution for crisp detail
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgContext = context.cgContext
            
            // Crisp black ocean base
            cgContext.setFillColor(UIColor.black.cgColor)
            cgContext.fill(rect)
            
            // Premium silver continents for Pulse branding
            let silverColor = UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0).cgColor
            cgContext.setFillColor(silverColor)
            
            // NORTH AMERICA - More accurate shape using longitude/latitude mapping
            // Longitude: ~-170° to -50° = x: 0.055 to 0.305
            // Latitude: ~15° to 75° = y: 0.125 to 0.625 (inverted)
            let northAmerica = CGMutablePath()
            
            // Alaska (far west)
            northAmerica.move(to: CGPoint(x: size.width * 0.07, y: size.height * 0.2))
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.12, y: size.height * 0.18),
                                control1: CGPoint(x: size.width * 0.09, y: size.height * 0.17),
                                control2: CGPoint(x: size.width * 0.11, y: size.height * 0.16))
            
            // Canada - northern border
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.28, y: size.height * 0.15),
                                control1: CGPoint(x: size.width * 0.18, y: size.height * 0.12),
                                control2: CGPoint(x: size.width * 0.25, y: size.height * 0.10))
            
            // Eastern Canada/US
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.32, y: size.height * 0.35),
                                control1: CGPoint(x: size.width * 0.30, y: size.height * 0.22),
                                control2: CGPoint(x: size.width * 0.33, y: size.height * 0.28))
            
            // US East Coast
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.30, y: size.height * 0.45),
                                control1: CGPoint(x: size.width * 0.31, y: size.height * 0.38),
                                control2: CGPoint(x: size.width * 0.305, y: size.height * 0.42))
            
            // Florida
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.285, y: size.height * 0.52),
                                control1: CGPoint(x: size.width * 0.295, y: size.height * 0.48),
                                control2: CGPoint(x: size.width * 0.29, y: size.height * 0.50))
            
            // Gulf of Mexico/Mexico
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.24, y: size.height * 0.58),
                                control1: CGPoint(x: size.width * 0.27, y: size.height * 0.55),
                                control2: CGPoint(x: size.width * 0.25, y: size.height * 0.565))
            
            // Central America
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.22, y: size.height * 0.62),
                                control1: CGPoint(x: size.width * 0.235, y: size.height * 0.595),
                                control2: CGPoint(x: size.width * 0.225, y: size.height * 0.61))
            
            // West Coast back up
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.18, y: size.height * 0.48),
                                control1: CGPoint(x: size.width * 0.20, y: size.height * 0.58),
                                control2: CGPoint(x: size.width * 0.185, y: size.height * 0.52))
            
            // California/West Coast
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.16, y: size.height * 0.35),
                                control1: CGPoint(x: size.width * 0.175, y: size.height * 0.44),
                                control2: CGPoint(x: size.width * 0.17, y: size.height * 0.39))
            
            // Pacific Northwest
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.15, y: size.height * 0.25),
                                control1: CGPoint(x: size.width * 0.155, y: size.height * 0.31),
                                control2: CGPoint(x: size.width * 0.145, y: size.height * 0.28))
            
            // Back to Alaska
            northAmerica.addCurve(to: CGPoint(x: size.width * 0.07, y: size.height * 0.2),
                                control1: CGPoint(x: size.width * 0.12, y: size.height * 0.22),
                                control2: CGPoint(x: size.width * 0.09, y: size.height * 0.21))
            
            cgContext.addPath(northAmerica)
            cgContext.fillPath()
            
            // SOUTH AMERICA - More accurate
            let southAmerica = CGMutablePath()
            southAmerica.move(to: CGPoint(x: size.width * 0.24, y: size.height * 0.62)) // Venezuela/Colombia
            southAmerica.addCurve(to: CGPoint(x: size.width * 0.29, y: size.height * 0.64),
                                control1: CGPoint(x: size.width * 0.26, y: size.height * 0.625),
                                control2: CGPoint(x: size.width * 0.28, y: size.height * 0.635))
            // Brazil bulge (east)
            southAmerica.addCurve(to: CGPoint(x: size.width * 0.31, y: size.height * 0.75),
                                control1: CGPoint(x: size.width * 0.305, y: size.height * 0.68),
                                control2: CGPoint(x: size.width * 0.315, y: size.height * 0.72))
            // Argentina
            southAmerica.addCurve(to: CGPoint(x: size.width * 0.26, y: size.height * 0.88),
                                control1: CGPoint(x: size.width * 0.295, y: size.height * 0.81),
                                control2: CGPoint(x: size.width * 0.275, y: size.height * 0.85))
            // Chile (west coast)
            southAmerica.addCurve(to: CGPoint(x: size.width * 0.22, y: size.height * 0.82),
                                control1: CGPoint(x: size.width * 0.245, y: size.height * 0.86),
                                control2: CGPoint(x: size.width * 0.23, y: size.height * 0.84))
            // Peru/Ecuador back to Colombia
            southAmerica.addCurve(to: CGPoint(x: size.width * 0.24, y: size.height * 0.62),
                                control1: CGPoint(x: size.width * 0.215, y: size.height * 0.75),
                                control2: CGPoint(x: size.width * 0.225, y: size.height * 0.68))
            
            cgContext.addPath(southAmerica)
            cgContext.fillPath()
            
            // EUROPE & AFRICA combined - More accurate
            let europeAfrica = CGMutablePath()
            // Scandinavia
            europeAfrica.move(to: CGPoint(x: size.width * 0.48, y: size.height * 0.12))
            europeAfrica.addCurve(to: CGPoint(x: size.width * 0.52, y: size.height * 0.15),
                                control1: CGPoint(x: size.width * 0.49, y: size.height * 0.125),
                                control2: CGPoint(x: size.width * 0.51, y: size.height * 0.135))
            // Eastern Europe/Russia
            europeAfrica.addCurve(to: CGPoint(x: size.width * 0.54, y: size.height * 0.25),
                                control1: CGPoint(x: size.width * 0.525, y: size.height * 0.18),
                                control2: CGPoint(x: size.width * 0.535, y: size.height * 0.22))
            // Mediterranean/North Africa
            europeAfrica.addCurve(to: CGPoint(x: size.width * 0.56, y: size.height * 0.42),
                                control1: CGPoint(x: size.width * 0.545, y: size.height * 0.32),
                                control2: CGPoint(x: size.width * 0.55, y: size.height * 0.37))
            // East Africa
            europeAfrica.addCurve(to: CGPoint(x: size.width * 0.58, y: size.height * 0.68),
                                control1: CGPoint(x: size.width * 0.57, y: size.height * 0.52),
                                control2: CGPoint(x: size.width * 0.575, y: size.height * 0.60))
            // Southern Africa
            europeAfrica.addCurve(to: CGPoint(x: size.width * 0.52, y: size.height * 0.82),
                                control1: CGPoint(x: size.width * 0.565, y: size.height * 0.75),
                                control2: CGPoint(x: size.width * 0.545, y: size.height * 0.79))
            // West Africa
            europeAfrica.addCurve(to: CGPoint(x: size.width * 0.45, y: size.height * 0.65),
                                control1: CGPoint(x: size.width * 0.495, y: size.height * 0.78),
                                control2: CGPoint(x: size.width * 0.47, y: size.height * 0.72))
            // Northwest Africa
            europeAfrica.addCurve(to: CGPoint(x: size.width * 0.46, y: size.height * 0.45),
                                control1: CGPoint(x: size.width * 0.43, y: size.height * 0.58),
                                control2: CGPoint(x: size.width * 0.44, y: size.height * 0.51))
            // Western Europe
            europeAfrica.addCurve(to: CGPoint(x: size.width * 0.48, y: size.height * 0.12),
                                control1: CGPoint(x: size.width * 0.465, y: size.height * 0.32),
                                control2: CGPoint(x: size.width * 0.475, y: size.height * 0.22))
            
            cgContext.addPath(europeAfrica)
            cgContext.fillPath()
            
            // ASIA - Much more accurate
            let asia = CGMutablePath()
            // Northern Russia/Siberia
            asia.move(to: CGPoint(x: size.width * 0.54, y: size.height * 0.15))
            asia.addCurve(to: CGPoint(x: size.width * 0.85, y: size.height * 0.12),
                        control1: CGPoint(x: size.width * 0.65, y: size.height * 0.10),
                        control2: CGPoint(x: size.width * 0.78, y: size.height * 0.08))
            // Eastern Russia/Kamchatka
            asia.addCurve(to: CGPoint(x: size.width * 0.88, y: size.height * 0.28),
                        control1: CGPoint(x: size.width * 0.87, y: size.height * 0.18),
                        control2: CGPoint(x: size.width * 0.885, y: size.height * 0.23))
            // China/Southeast Asia
            asia.addCurve(to: CGPoint(x: size.width * 0.82, y: size.height * 0.52),
                        control1: CGPoint(x: size.width * 0.87, y: size.height * 0.38),
                        control2: CGPoint(x: size.width * 0.845, y: size.height * 0.45))
            // India
            asia.addCurve(to: CGPoint(x: size.width * 0.72, y: size.height * 0.58),
                        control1: CGPoint(x: size.width * 0.79, y: size.height * 0.55),
                        control2: CGPoint(x: size.width * 0.755, y: size.height * 0.565))
            // Middle East/Central Asia back to Europe
            asia.addCurve(to: CGPoint(x: size.width * 0.54, y: size.height * 0.15),
                        control1: CGPoint(x: size.width * 0.65, y: size.height * 0.45),
                        control2: CGPoint(x: size.width * 0.58, y: size.height * 0.28))
            
            cgContext.addPath(asia)
            cgContext.fillPath()
            
            // AUSTRALIA - More accurate
            let australia = CGPath(ellipseIn: CGRect(x: size.width * 0.75, y: size.height * 0.72,
                                                   width: size.width * 0.08, height: size.height * 0.08), transform: nil)
            cgContext.addPath(australia)
            cgContext.fillPath()
            
            // MAJOR ISLANDS - More accurate positioning
            // Greenland
            let greenland = CGPath(ellipseIn: CGRect(x: size.width * 0.35, y: size.height * 0.08,
                                                   width: size.width * 0.04, height: size.height * 0.08), transform: nil)
            cgContext.addPath(greenland)
            cgContext.fillPath()
            
            // Madagascar
            let madagascar = CGPath(ellipseIn: CGRect(x: size.width * 0.57, y: size.height * 0.72,
                                                    width: size.width * 0.015, height: size.height * 0.06), transform: nil)
            cgContext.addPath(madagascar)
            cgContext.fillPath()
            
            // Japan
            let japan = CGPath(ellipseIn: CGRect(x: size.width * 0.87, y: size.height * 0.32,
                                               width: size.width * 0.02, height: size.height * 0.05), transform: nil)
            cgContext.addPath(japan)
            cgContext.fillPath()
            
            // New Zealand
            let newZealand = CGPath(ellipseIn: CGRect(x: size.width * 0.96, y: size.height * 0.78,
                                                   width: size.width * 0.015, height: size.height * 0.04), transform: nil)
            cgContext.addPath(newZealand)
            cgContext.fillPath()
            
            // UK/British Isles
            let uk = CGPath(ellipseIn: CGRect(x: size.width * 0.465, y: size.height * 0.22,
                                           width: size.width * 0.012, height: size.height * 0.03), transform: nil)
            cgContext.addPath(uk)
            cgContext.fillPath()
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
        private var isUserInteracting = false
        
        init(_ parent: GlobeSceneView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let sceneView = gesture.view as! SCNView
            let location = gesture.location(in: sceneView)
            
            let hitResults = sceneView.hitTest(location, options: [:])
            
            Task { @MainActor in
                for result in hitResults {
                    if let starId = result.node.name.flatMap({ UUID(uuidString: $0) }),
                       let star = parent.viewModel.stars.first(where: { $0.id == starId }) {
                        parent.selectedStar = star
                        parent.showStarDetails = true
                        break
                    }
                }
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let sceneView = sceneView,
                  let earthNode = sceneView.scene?.rootNode.childNode(withName: "earth", recursively: true) else { return }
            
            switch gesture.state {
            case .began:
                // User started interacting - pause auto-rotation
                isUserInteracting = true
                earthNode.removeAction(forKey: "autoRotation")
                autoRotationTimer?.invalidate()
                print("🤚 Globe: User interaction started - pausing auto-rotation")
                
            case .ended, .cancelled:
                // User stopped interacting - resume auto-rotation after a delay
                isUserInteracting = false
                autoRotationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    self?.resumeAutoRotation(for: earthNode)
                }
                print("⏱️ Globe: User interaction ended - resuming auto-rotation in 3s")
                
            default:
                break
            }
        }
        
        private func resumeAutoRotation(for earthNode: SCNNode) {
            guard !isUserInteracting else { return }
            
            // Resume the auto-rotation animation
            let rotationAction = SCNAction.rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: 30.0)
            let repeatAction = SCNAction.repeatForever(rotationAction)
            earthNode.runAction(repeatAction, forKey: "autoRotation")
            
            print("🔄 Globe: Auto-rotation resumed")
        }
        
        deinit {
            autoRotationTimer?.invalidate()
        }
        
        @MainActor func updateStars(_ stars: [GlobeStarEntity]) {
            guard let scene = parent.viewModel.sceneView?.scene else { return }
            
            // Remove old stars that are no longer present
            let currentStarIds = Set(stars.map { $0.id })
            let nodesToRemove = starNodes.filter { !currentStarIds.contains($0.key) }
            
            for (_, node) in nodesToRemove {
                node.removeFromParentNode()
            }
            starNodes = starNodes.filter { currentStarIds.contains($0.key) }
            
            // Add or update stars
            for star in stars {
                if let existingNode = starNodes[star.id] {
                    updateStarNode(existingNode, with: star)
                } else {
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
            let starGeometry = SCNSphere(radius: CGFloat(star.size * 0.02)) // Scale for visibility
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
            starNode.position = SCNVector3(coords.x * 1.01, coords.y * 1.01, coords.z * 1.01) // Slightly above surface
            
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
        
        private func updateStarNode(_ node: SCNNode, with star: GlobeStarEntity) {
            // Update star properties
            if let geometry = node.geometry as? SCNSphere {
                geometry.radius = CGFloat(star.size * 0.02)
            }
            
            if let material = node.geometry?.materials.first {
                let color = star.color.rgba
                material.emission.contents = UIColor(
                    red: CGFloat(color.red),
                    green: CGFloat(color.green),
                    blue: CGFloat(color.blue),
                    alpha: CGFloat(color.alpha * star.glowIntensity)
                )
            }
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
        
        private func convertToSphereCoordinates(_ location: CLLocationCoordinate2D) -> (x: Float, y: Float, z: Float) {
            let earthRadius: Float = 1.0
            
            // Convert degrees to radians
            let lat = Float(location.latitude) * .pi / 180.0
            let lon = Float(location.longitude) * .pi / 180.0
            
            // Standard spherical to Cartesian coordinate conversion
            // This matches the UV mapping of equirectangular Earth textures
            let x = earthRadius * cos(lat) * cos(lon)
            let y = earthRadius * sin(lat)
            let z = -earthRadius * cos(lat) * sin(lon) // Negative for correct orientation
            
            return (x, y, z)
        }
    }
}

// MARK: - Star Detail View
struct StarDetailView: View {
    let star: GlobeStarEntity
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
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
                
                Spacer()
            }
            .padding()
            .navigationTitle("Pulse Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

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
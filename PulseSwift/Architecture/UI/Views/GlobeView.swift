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
        
        // Create Earth sphere
        let earthGeometry = SCNSphere(radius: 1.0)
        let earthMaterial = SCNMaterial()
        earthMaterial.diffuse.contents = UIImage(named: "earth_texture_4k") ?? UIColor.blue
        earthMaterial.specular.contents = UIColor.white
        earthMaterial.shininess = 0.1
        earthGeometry.materials = [earthMaterial]
        
        let earthNode = SCNNode(geometry: earthGeometry)
        earthNode.name = "earth"
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
        
        return scene
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: GlobeSceneView
        private var starNodes: [UUID: SCNNode] = [:]
        private var pulseLineNodes: [UUID: SCNNode] = [:]
        
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
            let lat = Float(location.latitude) * .pi / 180.0
            let lon = Float(location.longitude) * .pi / 180.0
            
            let x = earthRadius * cos(lat) * cos(lon)
            let y = earthRadius * sin(lat)
            let z = earthRadius * cos(lat) * sin(lon)
            
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
                    
                    DetailRow(title: "Pulse Duration", value: formatDuration(star.pulseMatch.pulseDuration))
                    
                    DetailRow(title: "Photos Exchanged", value: "\(star.pulseMatch.photoCount)")
                    
                    DetailRow(title: "Date", value: star.pulseMatch.createdAt.formatted(date: .abbreviated, time: .shortened))
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
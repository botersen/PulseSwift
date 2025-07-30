import SwiftUI

// MARK: - Main App View (Camera + Globe Tabs)
struct MainAppView: View {
    @State private var selectedTab: MainAppTab = .camera
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Camera Tab
            CameraScreen()
                .tabItem {
                    Image(systemName: selectedTab == .camera ? "camera.fill" : "camera")
                    Text("Camera")
                }
                .tag(MainAppTab.camera)
            
            // Globe Tab
            GlobeView()
                .tabItem {
                    Image(systemName: selectedTab == .globe ? "globe.americas.fill" : "globe.americas")
                    Text("Globe")
                }
                .tag(MainAppTab.globe)
        }
        .accentColor(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        
        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.6)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ]
        
        // Selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Tab Enum
enum MainAppTab: CaseIterable {
    case camera
    case globe
    
    var title: String {
        switch self {
        case .camera: return "Camera"
        case .globe: return "Globe"
        }
    }
    
    var iconName: String {
        switch self {
        case .camera: return "camera"
        case .globe: return "globe.americas"
        }
    }
    
    var selectedIconName: String {
        switch self {
        case .camera: return "camera.fill"
        case .globe: return "globe.americas.fill"
        }
    }
}

// MARK: - Preview
struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
    }
} 
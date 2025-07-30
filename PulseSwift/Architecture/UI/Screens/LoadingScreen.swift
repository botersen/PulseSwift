import SwiftUI

// MARK: - Premium Launch Screen (Your Polished Design)
struct LoadingScreen: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.9
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
                Color.black.ignoresSafeArea()
                Text("PULSE")
                    .font(.custom("Special Gothic Expanded One", size: calculateFontSize(for: geometry.size.width)))
                    .foregroundColor(.white)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
                    .padding(.horizontal, 18) // ~quarter inch padding on each side
            }
        }
        .onAppear {
            // Start the logo animation with premium timing
            withAnimation(.easeOut(duration: 0.8)) {
                logoOpacity = 1.0
                logoScale = 1.0
                    }
                
            // Auto-transition after animation completes (industry standard)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // AppFlowViewModel will handle transition
            }
        }
    }
    
    private func calculateFontSize(for screenWidth: CGFloat) -> CGFloat {
        // Calculate font size to fill width minus padding (36 points = ~half inch total)
        // Optimized for Special Gothic Expanded One character width
        let availableWidth = screenWidth - 36
        return availableWidth * 0.25 // Refined for elegant display
    }
}

#Preview {
    LoadingScreen()
} 
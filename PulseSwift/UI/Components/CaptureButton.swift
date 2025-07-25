//
//  CaptureButton.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct CaptureButton: View {
    let isRecording: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    @State private var recordingScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .strokeBorder(PulseTheme.Colors.primary, lineWidth: 4)
                .frame(width: 80, height: 80)
                .scaleEffect(isPressed ? 0.95 : 1.0)
            
            // Inner button
            RoundedRectangle(cornerRadius: isRecording ? 8 : 30)
                .fill(isRecording ? PulseTheme.Colors.error : PulseTheme.Colors.primary)
                .frame(width: isRecording ? 32 : 60, height: isRecording ? 32 : 60)
                .scaleEffect(recordingScale)
                .animation(PulseTheme.Animation.medium, value: isRecording)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onTap()
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { _ in
                    if !isRecording {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        onLongPress()
                    }
                }
        )
        .animation(PulseTheme.Animation.fast, value: isPressed)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if isRecording {
                withAnimation(PulseTheme.Animation.fast) {
                    recordingScale = recordingScale == 1.0 ? 1.2 : 1.0
                }
            } else {
                recordingScale = 1.0
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        CaptureButton(isRecording: false, onTap: {}, onLongPress: {})
        CaptureButton(isRecording: true, onTap: {}, onLongPress: {})
    }
    .padding()
    .background(Color.black)
} 
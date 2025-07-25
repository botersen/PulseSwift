//
//  CaptionEditorView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct CaptionEditorView: View {
    @Binding var caption: String
    @Binding var isPresented: Bool
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissEditor()
                }
            
            VStack {
                Spacer()
                
                // Caption input area
                VStack(spacing: PulseTheme.Spacing.lg) {
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismissEditor()
                        }
                        .foregroundColor(PulseTheme.Colors.secondary)
                        
                        Spacer()
                        
                        Text("Add Caption")
                            .font(PulseTheme.Typography.body)
                            .foregroundColor(PulseTheme.Colors.primary)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Done") {
                            dismissEditor()
                        }
                        .foregroundColor(PulseTheme.Colors.primary)
                        .fontWeight(.semibold)
                    }
                    
                    // Text input
                    TextField("What's happening?", text: $caption, axis: .vertical)
                        .font(.custom("NotoSans-Regular", size: 16))
                        .foregroundColor(PulseTheme.Colors.primary)
                        .padding(PulseTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.md)
                                .fill(PulseTheme.Colors.glassBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.md)
                                        .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                                )
                        )
                        .focused($isTextFieldFocused)
                        .lineLimit(3...6)
                    
                    // Character count
                    HStack {
                        Spacer()
                        Text("\(caption.count)/280")
                            .font(PulseTheme.Typography.caption)
                            .foregroundColor(caption.count > 280 ? PulseTheme.Colors.error : PulseTheme.Colors.secondary)
                    }
                }
                .padding(PulseTheme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.lg)
                        .fill(PulseTheme.Colors.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.lg)
                                .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                        )
                )
                .padding(.horizontal, PulseTheme.Spacing.lg)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func dismissEditor() {
        isTextFieldFocused = false
        withAnimation(PulseTheme.Animation.medium) {
            isPresented = false
        }
    }
}

#Preview {
    CaptionEditorView(
        caption: .constant(""),
        isPresented: .constant(true)
    )
} 
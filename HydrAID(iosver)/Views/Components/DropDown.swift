//
//  DropDown.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.07.
//

import SwiftUI

struct DropdownSection<Content: View>: View {
    @State private var isExpanded: Bool = false
    let title: String
    let content: Content
    let accentColor: Color
    
    init(title: String, accentColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accentColor = accentColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Dropdown header/button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.vertical, 6)
            .accessibilityHint(Text(isExpanded ? "Tap to collapse" : "Tap to expand"))
            
            // Dropdown content
            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
    }
}

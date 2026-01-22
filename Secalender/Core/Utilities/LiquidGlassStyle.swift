//
//  LiquidGlassStyle.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI

// MARK: - Liquid Glass 样式扩展
extension View {
    /// 应用玻璃态卡片样式
    func glassCard(radius: CGFloat = 16, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
    }
    
    /// 应用玻璃态按钮样式
    func glassButton(radius: CGFloat = 12) -> some View {
        self
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    /// 应用玻璃态浮动按钮样式
    func glassFloatingButton(size: CGFloat = 60) -> some View {
        self
            .frame(width: size, height: size)
            .background(
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                }
            )
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
            .shadow(color: .white.opacity(0.3), radius: 1, x: 0, y: -1)
    }
    
    /// 应用玻璃态背景
    func glassBackground() -> some View {
        self
            .background(
                ZStack {
                    // 渐变背景
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.05),
                            Color.primary.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // 材质层
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            )
    }
    
    /// 应用玻璃态标签样式
    func glassTag(isSelected: Bool, radius: CGFloat = 20) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(.thinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: radius)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.6),
                                                Color.blue.opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: radius)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: radius)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            )
            .shadow(
                color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
    }
}

// MARK: - 玻璃态卡片组件
struct GlassCard<Content: View>: View {
    let content: Content
    let radius: CGFloat
    let padding: CGFloat
    
    init(radius: CGFloat = 16, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.3),
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
    }
}

// MARK: - 玻璃态按钮组件
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }
    
    init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundGradient, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 10, x: 0, y: 5)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .secondary:
            return .primary
        case .destructive:
            return .white
        }
    }
    
    private var backgroundGradient: some ShapeStyle {
        switch style {
        case .primary:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.6),
                        Color.blue.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .destructive:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.7),
                        Color.red.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary:
            return .blue.opacity(0.3)
        case .secondary:
            return .black.opacity(0.1)
        case .destructive:
            return .red.opacity(0.3)
        }
    }
}

// MARK: - 玻璃态成功提示
struct GlassSuccessToast: View {
    let message: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.green)
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .shadow(color: .green.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

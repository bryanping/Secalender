
//
//  SkeletonEventView.swift
//  Secalender
//
//  Created by AI Assistant on 2024/12/19.
//

import SwiftUI

// 静态骨架屏组件 - 无动画，性能最佳
struct StaticSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 日期标题
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 50, height: 14)
                Spacer()
            }
            
            // 事件卡片
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 35, height: 12)
                
                VStack(alignment: .leading, spacing: 3) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 100, height: 12)
                    Rectangle()
                        .fill(Color.gray.opacity(0.08))
                        .frame(width: 60, height: 8)
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.02))
            .cornerRadius(4)
        }
        .padding(.horizontal)
    }
}

struct SkeletonEventView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 简化的日期标题骨架
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 16)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 12)
            }
            
            // 简化的事件卡片骨架 - 只显示一个
            HStack(spacing: 8) {
                // 时间骨架
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 14)
                
                // 事件内容骨架
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 14)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 80, height: 10)
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)
        }
        .padding(.horizontal)
        .opacity(isAnimating ? 0.7 : 1.0)
        .animation(
            Animation.easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            // 延迟启动动画，避免立即开始
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimating = true
            }
        }
    }
}

// 更轻量级的骨架屏组件
struct FastSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 日期标题
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 50, height: 14)
                Spacer()
            }
            
            // 事件卡片
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 35, height: 12)
                
                VStack(alignment: .leading, spacing: 3) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 100, height: 12)
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 60, height: 8)
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.03))
            .cornerRadius(4)
        }
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        StaticSkeletonView()
        SkeletonEventView()
        FastSkeletonView()
    }
}

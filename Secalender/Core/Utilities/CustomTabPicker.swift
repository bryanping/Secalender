//
//  CustomTabPicker.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  自定义Tab选择器，参考图片样式
//

import SwiftUI

struct CustomTabPicker<T: Hashable>: View {
    let tabs: [(title: String, value: T)]
    @Binding var selection: T
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = tab.value
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.system(size: 16, weight: selection == tab.value ? .semibold : .regular))
                            .foregroundColor(selection == tab.value ? .blue : .gray)
                        
                        // 下划线
                        Rectangle()
                            .fill(selection == tab.value ? Color.blue : Color.clear)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}

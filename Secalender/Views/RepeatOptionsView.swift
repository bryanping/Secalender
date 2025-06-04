//
//  RepeatOptionsView.swift
//  Secalender
//
//  Created by Assistant on 2024/7/27.
//

import SwiftUI

struct RepeatOptionsView: View {
    @Binding var selectedRepeat: String
    @Environment(\.dismiss) var dismiss
    
    private let repeatOptions = [
        ("never", "永不"),
        ("daily", "每天"),
        ("weekly", "每週"),
        ("monthly", "每月"),
        ("yearly", "每年")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(repeatOptions, id: \.0) { option in
                    HStack {
                        Text(option.1)
                        Spacer()
                        if selectedRepeat == option.0 {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRepeat = option.0
                        dismiss()
                    }
                }
            }
            .navigationTitle("重複")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RepeatOptionsView(selectedRepeat: .constant("never"))
}
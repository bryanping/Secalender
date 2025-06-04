//
//  TravelTimeOptionsView.swift
//  Secalender
//
//  Created by Assistant on 2024/7/27.
//

import SwiftUI

struct TravelTimeOptionsView: View {
    @Binding var selectedTravelTime: String?
    @Environment(\.dismiss) var dismiss
    
    private let travelTimeOptions = [
        ("無", nil),
        ("5 分鐘", "5"),
        ("15 分鐘", "15"),
        ("30 分鐘", "30"),
        ("1 小時", "60"),
        ("1.5 小時", "90"),
        ("2 小時", "120")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(travelTimeOptions, id: \.0) { option in
                    HStack {
                        Text(option.0)
                        Spacer()
                        if selectedTravelTime == option.1 {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTravelTime = option.1
                        dismiss()
                    }
                }
            }
            .navigationTitle("路程時間")
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
    TravelTimeOptionsView(selectedTravelTime: .constant(nil))
}
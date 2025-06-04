//
//  CalendarOptionsView.swift
//  Secalender
//
//  Created by Assistant on 2024/7/27.
//

import SwiftUI

struct CalendarOptionsView: View {
    @Binding var selectedCalendar: String
    @Environment(\.dismiss) var dismiss
    
    private let calendarOptions = [
        ("default", "活動安排", Color.red),
        ("work", "工作", Color.blue),
        ("personal", "個人", Color.green),
        ("family", "家庭", Color.orange),
        ("study", "學習", Color.purple)
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(calendarOptions, id: \.0) { option in
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(option.2)
                        Text(option.1)
                        Spacer()
                        if selectedCalendar == option.0 {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCalendar = option.0
                        dismiss()
                    }
                }
            }
            .navigationTitle("行事曆")
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
    CalendarOptionsView(selectedCalendar: .constant("default"))
}
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
    
    private var repeatOptions: [(String, String)] {
        [
            ("never", "event_create.repeat_options.never".localized()),
            ("daily", "event_create.repeat_options.daily".localized()),
            ("weekly", "event_create.repeat_options.weekly".localized()),
            ("monthly", "event_create.repeat_options.monthly".localized()),
            ("yearly", "event_create.repeat_options.yearly".localized())
        ]
    }
    
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
            .navigationTitle("repeat_options.title".localized())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("repeat_options.done".localized()) {
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
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
    
    private var travelTimeOptions: [(String, String?)] {
        [
            ("event_create.travel_time.none".localized(), nil),
            ("event_create.travel_time.minutes".localized(with: 5), "5"),
            ("event_create.travel_time.minutes".localized(with: 15), "15"),
            ("event_create.travel_time.minutes".localized(with: 30), "30"),
            ("event_create.travel_time.hours".localized(with: 1.0), "60"),
            ("event_create.travel_time.hours".localized(with: 1.5), "90"),
            ("event_create.travel_time.hours".localized(with: 2.0), "120")
        ]
    }
    
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
            .navigationTitle("travel_time.title".localized())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("travel_time.done".localized()) {
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
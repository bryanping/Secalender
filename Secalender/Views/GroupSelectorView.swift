//
//  GroupSelectorView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI

/// 社群选择器视图
struct GroupSelectorView: View {
    let groups: [CommunityGroup]
    @Binding var selectedGroupId: String?
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groups, id: \.id) { group in
                    Button(action: {
                        selectedGroupId = group.id
                        onSelect(group.id)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if !group.description.isEmpty {
                                    Text(group.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Text("成員: \(group.members.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedGroupId == group.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("選擇社群")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

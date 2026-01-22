//
//  TemplateStoreView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  模板市集页面
//

import SwiftUI

struct TemplateStoreView: View {
    @State private var templates: [StoreTemplate] = [
        StoreTemplate(
            id: UUID(),
            title: "東京3日遊",
            description: "經典東京景點，包含淺草寺、東京鐵塔、新宿等",
            tags: ["東京", "文化", "購物"],
            price: 299
        ),
        StoreTemplate(
            id: UUID(),
            title: "京都深度文化之旅",
            description: "探索古都京都的傳統文化與歷史",
            tags: ["京都", "文化", "歷史"],
            price: 399
        ),
        StoreTemplate(
            id: UUID(),
            title: "大阪美食之旅",
            description: "品嚐大阪道地美食，體驗當地文化",
            tags: ["大阪", "美食", "文化"],
            price: 349
        )
    ]
    
    var body: some View {
        List {
            Section(header: Text("熱門推薦")) {
                ForEach(templates) { template in
                    NavigationLink(destination: TemplateDetailView(template: template)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title).font(.headline)
                            Text(template.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                ForEach(template.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Text(String(format: "NT$%.0f", template.price))
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80) // 为TabBar预留空间
        }
    }
}

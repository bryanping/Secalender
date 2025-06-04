//
//  TemplateStoreView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//

import SwiftUI

struct Template: Identifiable {
    let id: UUID = UUID()
    var title: String
    var description: String
    var price: Double
    var tags: [String]
}

struct TemplateStoreView: View {
    @State private var templates: [Template] = [
        Template(title: "日本三天兩夜自由行",
                 description: "包含住宿、景點與交通的完整行程規劃範本",
                 price: 149.0,
                 tags: ["旅遊", "日本", "自由行"]),
        Template(title: "親子樂園一日遊",
                 description: "適合帶孩子出遊的遊樂園行程安排",
                 price: 99.0,
                 tags: ["親子", "一日遊"]),
        Template(title: "高效工作日程規劃",
                 description: "專為自由工作者設計的時間管理模板",
                 price: 49.0,
                 tags: ["工作", "效率"])
    ]

    var body: some View {
        NavigationView {
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
            .navigationTitle("模板市集")
        }
    }
}

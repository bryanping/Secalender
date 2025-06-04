//
//  TemplateDetailView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//

import SwiftUI

struct TemplateDetailView: View {
    let template: Template
    @State private var showingPurchaseAlert = false
    @State private var purchased = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(template.title).font(.title).bold()
            Text(template.description).font(.body)
            HStack {
                ForEach(template.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            Text(String(format: "NT$%.0f", template.price))
                .font(.title3)
                .foregroundColor(.green)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    // 真正的購買邏輯請整合您的支付方案
                    showingPurchaseAlert = true
                }) {
                    Text(purchased ? "已購買" : "購買模板")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(purchased ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(purchased)

                Button(action: {
                    // 套用模板至行事曆的邏輯
                    showingPurchaseAlert = true
                }) {
                    Text("套用至行事曆")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!purchased)
            }
        }
        .padding()
        .navigationBarTitle("模板詳情", displayMode: .inline)
        .alert(isPresented: $showingPurchaseAlert) {
            if purchased {
                return Alert(title: Text("提示"),
                             message: Text("已將模板套用至您的行事曆。"),
                             dismissButton: .default(Text("確認")))
            } else {
                purchased = true
                return Alert(title: Text("購買成功"),
                             message: Text("感謝購買！您現在可以套用此模板。"),
                             dismissButton: .default(Text("好的")))
            }
        }
    }
}

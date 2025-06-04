//
//  AIPlannerView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//

import SwiftUI

struct AIPlannerView: View {
    @State private var inputText: String = ""
    @State private var suggestedPlan: String?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("輸入您的需求").font(.headline)
                TextField("例如：安排一趟親子週末旅遊", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if let plan = suggestedPlan {
                    Divider()
                    Text("AI 建議行程：").font(.headline)
                    ScrollView {
                        Text(plan)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()

                Button(action: generatePlan) {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("生成建議行程")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("AI 智能規劃")
        }
    }

    private func generatePlan() {
        guard !inputText.isEmpty else { return }
        isLoading = true
        suggestedPlan = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.suggestedPlan = """
            根據您的需求，建議行程如下：
            1. 上午：出發前往目的地並享受早餐。
            2. 中午：參觀當地景點並用午餐。
            3. 下午：安排戶外活動與休閒時間。
            4. 晚上：返回住宿並總結一天。
            """
            self.isLoading = false
        }
    }
}

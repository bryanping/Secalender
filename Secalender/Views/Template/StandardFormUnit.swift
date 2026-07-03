import SwiftUI

/// 統一的表單單元外觀（供主題表單、行程規劃等共用）
struct StandardFormUnit<Content: View>: View {
    let title: String
    let subtitle: String?
    let isRequired: Bool
    @ViewBuilder let content: () -> Content
    
    init(title: String, subtitle: String? = nil, isRequired: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.isRequired = isRequired
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    
                    if isRequired {
                        Text("＊")
                            .font(.headline)
                            .foregroundColor(.red)
                            .accessibilityLabel("必填")
                    }
                    
                    Spacer(minLength: 0)
                }
                
                if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            content()
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
        )
    }
}

extension View {
    /// 統一輸入框內層樣式（避免每個題型各自調 padding/背景）
    func standardFieldContainer() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.systemGray4).opacity(0.35), lineWidth: 1)
            )
    }
}


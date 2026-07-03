//
//  PublishingHistoryView.swift
//  Secalender
//
//  發佈紀錄：公開內容的發佈時間線，使用 InfluenceDataManager 活動紀錄
//

import SwiftUI

struct PublishingHistoryView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @StateObject private var influenceManager = InfluenceDataManager.shared
    
    private var items: [ActivityLog] { influenceManager.publishingHistory }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    private func typeLabel(for log: ActivityLog) -> String {
        switch log.type {
        case .eventCreated: return "member.assets_plans".localized()
        case .templateCreated: return "member.assets_templates".localized()
        case .themeCreated: return "member.assets_themes".localized()
        case .aiUsed: return "AI"
        case .eventParticipated: return "member.event_invitations".localized()
        case .contentPublished: return "member.publish_history_title".localized()
        default: return log.type.rawValue
        }
    }
    
    var body: some View {
        ScrollView {
            if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("member.publish_history_empty".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title ?? typeLabel(for: item))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                HStack {
                                    Text(typeLabel(for: item))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let v = item.visibility {
                                        Text(v)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(Self.dateFormatter.string(from: item.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.publish_history_title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await influenceManager.load(for: userManager.userOpenId)
        }
        .refreshable {
            await influenceManager.load(for: userManager.userOpenId)
        }
    }
}

#Preview {
    NavigationView {
        PublishingHistoryView()
            .environmentObject(FirebaseUserManager.shared)
    }
}

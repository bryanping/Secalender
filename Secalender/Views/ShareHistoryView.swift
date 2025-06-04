//
//  ShareHistoryView.swift
//  Secalender
//

import SwiftUI

struct ShareHistoryView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var sharedEvents: [Event] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载分享历史...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sharedEvents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无分享历史")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("你分享的活动将显示在这里")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sharedEvents, id: \.id) { event in
                            NavigationLink(destination: EventShareView(event: event)) {
                                SharedEventRow(event: event)
                            }
                        }
                    }
                    .refreshable {
                        await loadSharedEvents()
                    }
                }
                
                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("分享历史")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await loadSharedEvents()
                }
            }
        }
    }
    
    private func loadSharedEvents() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allEvents = try await EventManager.shared.fetchEvents()
            // 过滤出用户分享过的活动（只要 openChecked == 1 即为公开分享）
            let shared = allEvents.filter { event in
                event.creatorOpenid == userManager.userOpenId && event.isOpenChecked
            }
            await MainActor.run {
                self.sharedEvents = shared.sorted { 
                    ($0.startDateTime ?? .distantPast) > ($1.startDateTime ?? .distantPast)
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// 分享活动行组件
struct SharedEventRow: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if event.isOpenChecked {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
                    .font(.caption)
                Text(event.date)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(.gray)
                    .font(.caption)
                Text(event.startTime)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if !event.destination.isEmpty {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text(event.destination)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            HStack {
                if event.isOpenChecked {
                    Text("公开给好友")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                Spacer()
                Text("分享于 \(event.createTime)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
} 
 
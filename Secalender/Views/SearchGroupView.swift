//
//  SearchGroupView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import Firebase

/// 搜索社群視圖
struct SearchGroupView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [CommunityGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showJoinSuccess = false
    @State private var joiningGroupId: String?
    
    // 防抖和去重：避免重复请求
    @State private var searchTask: Task<Void, Never>?
    @State private var lastSearchQuery: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索欄
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("輸入社群名稱或ID", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            triggerSearch()
                        }
                        .onChange(of: searchQuery) { oldValue, newValue in
                            // 当用户清空搜索时，清空结果
                            if newValue.isEmpty {
                                cancelSearch()
                                searchResults = []
                            }
                        }
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // 搜索按鈕
                Button {
                    triggerSearch()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("搜索")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(searchQuery.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(searchQuery.isEmpty || isLoading)
                .padding(.horizontal)
                
                // 結果列表
                if isLoading {
                    Spacer()
                    ProgressView("搜索中...")
                    Spacer()
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("未找到符合條件的社群")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("請嘗試使用不同的關鍵詞或社群ID")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if !searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(searchResults, id: \.id) { group in
                                GroupSearchResultRow(
                                    group: group,
                                    currentUserId: userManager.userOpenId,
                                    onJoin: { groupId in
                                        await joinGroup(groupId: groupId)
                                    },
                                    isJoining: joiningGroupId == group.id
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("搜索社群")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("輸入社群名稱或ID進行搜索\n名稱相似度需達到50%以上")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
            }
            .navigationTitle("搜索社群")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知錯誤")
            }
            .alert("加入成功", isPresented: $showJoinSuccess) {
                Button("確定", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("已成功加入社群")
            }
        }
    }
    
    /// 触发搜索（带防抖和去重）
    private func triggerSearch() {
        // 取消之前的搜索任务
        searchTask?.cancel()
        
        // 避免重复搜索相同的查询
        guard !searchQuery.isEmpty && searchQuery != lastSearchQuery else {
            return
        }
        
        // 避免在加载中时重复触发
        guard !isLoading else {
            return
        }
        
        lastSearchQuery = searchQuery
        
        // 创建新的搜索任务（带 300ms 防抖）
        searchTask = Task {
            // 等待 300ms，如果用户继续输入则取消
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            // 检查任务是否被取消或查询是否已改变
            guard !Task.isCancelled && searchQuery == lastSearchQuery else {
                return
            }
            
            await performSearch()
        }
    }
    
    /// 取消搜索任务
    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        lastSearchQuery = ""
    }
    
    /// 执行搜索
    private func performSearch() async {
        // 再次检查避免重复请求
        guard !searchQuery.isEmpty else { return }
        
        // 检查是否已在加载中（避免并发请求）
        let shouldStart: Bool = await MainActor.run {
            guard !isLoading else { return false }
            isLoading = true
            errorMessage = nil
            searchResults = []
            return true
        }
        
        guard shouldStart else { return }
        
        do {
            let results = try await GroupManager.shared.searchGroups(query: searchQuery, minSimilarity: 0.5)
            
            // 确保查询未改变后再更新结果
            guard searchQuery == lastSearchQuery else {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            await MainActor.run {
                searchResults = results
                isLoading = false
            }
        } catch {
            // 确保查询未改变后再更新错误
            guard searchQuery == lastSearchQuery else {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            await MainActor.run {
                errorMessage = "搜索失敗：\(error.localizedDescription)"
                showErrorAlert = true
                isLoading = false
            }
        }
    }
    
    private func joinGroup(groupId: String) async {
        // 避免重复加入（在主线程检查）
        let shouldStart: Bool = await MainActor.run {
            guard joiningGroupId == nil else { return false }
            joiningGroupId = groupId
            return true
        }
        
        guard shouldStart else { return }
        
        defer {
            Task { @MainActor in
                joiningGroupId = nil
            }
        }
        
        do {
            // 檢查社群權限
            let group = try await GroupManager.shared.getGroup(groupId: groupId)
            
            await MainActor.run {
                if group.privacy == .review {
                    // 審核權限：需要發送申請，暫時使用公開加入（實際應該有申請機制）
                    // TODO: 實現申請加入機制
                } else if group.privacy == .public {
                    // 自由權限：直接加入
                } else {
                    // 私人社群不應該出現在搜索結果中
                    errorMessage = "無法加入該社群"
                    showErrorAlert = true
                    return
                }
            }
            
            // 执行加入操作（异步）
            try await GroupManager.shared.joinGroupPublicly(
                groupId: groupId,
                userId: userManager.userOpenId
            )
            
            // 更新成功状态（主线程）
            await MainActor.run {
                showJoinSuccess = true
            }
        } catch {
            await MainActor.run {
                if case GroupError.memberAlreadyExists = error {
                    errorMessage = "您已經是該社群的成員"
                } else {
                    errorMessage = "加入失敗：\(error.localizedDescription)"
                }
                showErrorAlert = true
            }
        }
    }
}

// MARK: - 搜索結果行視圖
struct GroupSearchResultRow: View {
    let group: CommunityGroup
    let currentUserId: String
    let onJoin: (String) async -> Void
    let isJoining: Bool
    
    var isAlreadyMember: Bool {
        group.members.contains(currentUserId)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 社群圖標
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Circle()
                    .fill(.ultraThinMaterial)
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 56, height: 56)
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .blue.opacity(0.2), radius: 8, x: 0, y: 4)
            
            // 社群信息
            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if !group.description.isEmpty {
                    Text(group.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // 顯示分類和地點
                HStack(spacing: 8) {
                    if let category = group.category {
                        Label(category, systemImage: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if let location = group.location {
                        Label(location, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 12) {
                    Text("\(group.members.count) 位成員")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    // 顯示權限標籤
                    Text(group.privacy.displayName)
                        .font(.caption2)
                        .foregroundColor(group.privacy == .public ? .green : group.privacy == .review ? .orange : .gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(group.privacy == .public ? Color.green.opacity(0.1) : group.privacy == .review ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    if let groupId = group.id {
                        Text("ID: \(groupId.prefix(8))...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 加入按鈕
            if isAlreadyMember {
                Label("已加入", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Button {
                    guard let groupId = group.id else { return }
                    Task {
                        await onJoin(groupId)
                    }
                } label: {
                    if isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(group.privacy == .review ? "申請加入" : "加入")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isJoining)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

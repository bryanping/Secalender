//
//  AddFriendView.swift
//  Secalender
//
//  Created by linping on 2024/7/1.
//

import SwiftUI
import Firebase
import AVFoundation
import AudioToolbox

struct AddFriendView: View {
    /// 透過 Deep Link 預填的邀請碼（如 https://secalender.app/friend/xxx）
    var prefilledInviteCode: String? = nil
    
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var searchInput: String = ""
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    @State private var isLoading = false
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var inviteLink: String = ""
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showQRCodeScanner = false
    @State private var myQRCodeImage: UIImage?
    @State private var qrCodeContent: String = ""
    @State private var sentRequests: [SentFriendRequest] = []
    @State private var isLoadingSentRequests = false
    @State private var showMessageInput = false
    @State private var pendingFriendRequest: PendingFriendRequest?
    @State private var messageText: String = ""
    
    struct PendingFriendRequest {
        let userId: String
        let userName: String
        let source: RequestSource
        
        enum RequestSource {
            case searchResult(SearchResult)
            case qrCode(String)  // userCode or userId
            case inviteLink(String)  // Firestore document ID from friend invite link
        }
    }
    
    struct SentFriendRequest: Identifiable {
        let id: String
        let requestId: String
        let targetUserId: String
        let targetUserName: String
        let targetUserCode: String?
        let targetPhotoUrl: String?
        let status: RequestStatus
        let createdAt: Date?
        let message: String?  // 新增时留言
        
        enum RequestStatus {
            case pending  // 等待验证
            case accepted // 已新增
            case rejected
            case cancelled
            
            var displayText: String {
                switch self {
                case .pending: return "等待验证"
                case .accepted: return "已新增"
                case .rejected: return "已拒绝"
                case .cancelled: return "已取消"
                }
            }
        }
    }
    
    struct SearchResult: Identifiable {
        let id: String
        let name: String
        let userId: String
        let userCode: String?
        let photoUrl: String?
        let mutualFriends: Int
        let friendStatus: FriendStatus
        
        enum FriendStatus {
            case notFriend
            case requestSent
            case alreadyFriend
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if userManager.userOpenId.isEmpty {
                    ProgressView("friends.loading".localized())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 搜索栏
                            searchBarView
                            
                            // 操作卡片：邀请链接和扫码添加
                            actionCardsView
                            
                            // 已发送的请求列表

                            
                            if !sentRequests.isEmpty {
                                sentRequestsView
                            }
                            
                            // 搜索结果
                            if !searchResults.isEmpty {
                                searchResultsView
                            }
                            
                            // 搜索无结果时的提示
                            if !searchInput.isEmpty, !isSearching, searchResults.isEmpty {
                                searchNoResultsView
                            }
                            
                            Spacer()
                                .frame(height: 24)

                            // 我的二维码
                            myQRCodeView
                                .padding(.top)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(.keyboard)
                }
            }
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if !shareItems.isEmpty {
                    ShareSheet(activityItems: shareItems)
                }
            }
            .sheet(isPresented: $showQRCodeScanner) {
                QRCodeScannerView { code in
                    handleScannedCode(code)
                }
            }
            .sheet(isPresented: $showMessageInput) {
                messageInputView
            }
            .task {
                await generateMyQRCode()
                await loadSentRequests()
                if let code = prefilledInviteCode, !code.isEmpty {
                    await handlePrefilledInviteCode(code)
                }
            }
            .refreshable {
                await loadSentRequests()
            }
        }
    }
    
    // MARK: - 搜索栏
    @ViewBuilder
    private var searchBarView: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
            
            TextField("搜尋手機號碼 / UserID", text: $searchInput)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onSubmit {
                    Task {
                        await performSearch()
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 操作卡片
    @ViewBuilder
    private var actionCardsView: some View {
        HStack(spacing: 12) {
            // 邀请链接卡片
            Button {
                Task {
                    await handleInviteLink()
                }
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "link")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(height: 40)
                    
                    Text("邀請連結")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            // 扫码添加卡片
            Button {
                showQRCodeScanner = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(height: 40)
                    
                    Text("掃碼添加")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 已发送的请求列表
    @ViewBuilder
    private var sentRequestsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("已發送的請求")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("共\(sentRequests.count)位")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            ForEach(sentRequests) { request in
                sentRequestRow(request)
            }
        }
    }
    
    @ViewBuilder
    private func sentRequestRow(_ request: SentFriendRequest) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像
            if let urlStr = request.targetPhotoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 20))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                    )
            }
            
            // 用户信息和状态
            HStack(alignment: .top, spacing: 8) {
                // 用户信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.targetUserName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // 如果有留言，显示留言
                    if let message = request.message, !message.isEmpty {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // 状态
                HStack(spacing: 4) {
                    Text("------ ")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(request.status.displayText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusColor(for: request.status))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func statusColor(for status: SentFriendRequest.RequestStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .rejected, .cancelled:
            return .gray
        }
    }
    
    private func statusBackgroundColor(for status: SentFriendRequest.RequestStatus) -> Color {
        switch status {
        case .pending:
            return Color.orange.opacity(0.1)
        case .accepted:
            return Color.green.opacity(0.1)
        case .rejected, .cancelled:
            return Color.gray.opacity(0.1)
        }
    }
    
    // MARK: - 搜索结果
    @ViewBuilder
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("搜尋結果")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("共\(searchResults.count)位")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            ForEach(searchResults) { result in
                searchResultRow(result)
            }
        }
    }
    
    @ViewBuilder
    private func searchResultRow(_ result: SearchResult) -> some View {
        HStack(spacing: 16) {
            // 头像
            if let urlStr = result.photoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 24))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                    )
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("ID: \(result.userCode ?? result.userId)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(result.mutualFriends)位共同好友")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            Button {
                Task {
                    await handleAddFriend(result)
                }
            } label: {
                Text(buttonText(for: result.friendStatus))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(buttonTextColor(for: result.friendStatus))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(buttonBackgroundColor(for: result.friendStatus), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(result.friendStatus != .notFriend)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 底部二维码
    @ViewBuilder
    private var myQRCodeView: some View {
        VStack(spacing: 12) {
            Text("我的二维码")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            if let qrImage = myQRCodeImage {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                ProgressView()
                    .frame(width: 120, height: 120)
            }
            
            if let userCode = userManager.userCode {
                Text("ID: \(userCode)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - 搜索无结果提示
    @ViewBuilder
    private var searchNoResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            
            Text("未找到相关用户")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Text("请检查手机号/UserID是否正确")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 辅助方法
    private func buttonText(for status: SearchResult.FriendStatus) -> String {
        switch status {
        case .notFriend:
            return "添加"
        case .requestSent:
            return "已發送"
        case .alreadyFriend:
            return "已是好友"
        }
    }
    
    private func buttonTextColor(for status: SearchResult.FriendStatus) -> Color {
        switch status {
        case .notFriend:
            return .white
        case .requestSent, .alreadyFriend:
            return .secondary
        }
    }
    
    private func buttonBackgroundColor(for status: SearchResult.FriendStatus) -> Color {
        switch status {
        case .notFriend:
            return .blue
        case .requestSent, .alreadyFriend:
            return Color(.systemGray5)
        }
    }

    // MARK: - 搜索功能
    private func performSearch() async {
        guard !searchInput.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let db = Firestore.firestore()
            var foundUsers: [(String, [String: Any])] = []
            
            // 通过 user_code 搜索
            let userCodeSnapshot = try await db.collection("users")
                .whereField("user_code", isEqualTo: searchInput.uppercased())
                .getDocuments()
            
            for doc in userCodeSnapshot.documents {
                if let data = doc.data() as? [String: Any] {
                    foundUsers.append((doc.documentID, data))
                }
            }
            
            // 通过手机号搜索
            let phoneSnapshot = try await db.collection("users")
                .whereField("phone", isEqualTo: searchInput)
                .getDocuments()
            
            for doc in phoneSnapshot.documents {
                if let data = doc.data() as? [String: Any] {
                    foundUsers.append((doc.documentID, data))
                }
            }
            
            // 通过邮箱搜索
            let emailSnapshot = try await db.collection("users")
                .whereField("email", isEqualTo: searchInput)
                .getDocuments()
            
            for doc in emailSnapshot.documents {
                if let data = doc.data() as? [String: Any] {
                    foundUsers.append((doc.documentID, data))
                }
            }
            
            // 转换为搜索结果
            var results: [SearchResult] = []
            for (userId, data) in foundUsers {
                // 跳过自己
                if userId == userManager.userOpenId {
                    continue
                }
                
                let name = (data["display_name"] as? String) ?? 
                          (data["alias"] as? String) ?? 
                          (data["name"] as? String) ?? 
                          (data["email"] as? String) ?? 
                          "未知用户"
                let userCode = data["user_code"] as? String
                let photoUrl = data["photo_url"] as? String
                
                // 检查好友状态
                let friendStatus = await checkFriendStatus(targetUserId: userId)
                
                // 计算共同好友数量（简化版，实际可能需要更复杂的查询）
                let mutualFriends = await getMutualFriendsCount(targetUserId: userId)
                
                results.append(SearchResult(
                    id: userId,
                    name: name,
                    userId: userId,
                    userCode: userCode,
                    photoUrl: photoUrl,
                    mutualFriends: mutualFriends,
                    friendStatus: friendStatus
                ))
            }
            
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "搜索失败：\(error.localizedDescription)"
                isSearching = false
            }
        }
    }
    
    // MARK: - 检查好友状态
    private func checkFriendStatus(targetUserId: String) async -> SearchResult.FriendStatus {
        do {
            // 检查是否已经是好友
            let friends = await FriendManager.shared.getFriends(for: userManager.userOpenId)
            if friends.contains(where: { $0.id == targetUserId }) {
                return .alreadyFriend
            }
            
            // 检查是否已发送请求
            let db = Firestore.firestore()
            let requestQuery = db.collection("friend_requests")
                .whereField("from", isEqualTo: userManager.userOpenId)
                .whereField("to", isEqualTo: targetUserId)
                .whereField("status", isEqualTo: "pending")
            
            let snapshot = try await requestQuery.getDocuments()
            if !snapshot.documents.isEmpty {
                return .requestSent
            }
            
            return .notFriend
        } catch {
            return .notFriend
        }
    }
    
    // MARK: - 获取共同好友数量
    private func getMutualFriendsCount(targetUserId: String) async -> Int {
        do {
            let myFriends = await FriendManager.shared.getFriends(for: userManager.userOpenId)
            let theirFriends = await FriendManager.shared.getFriends(for: targetUserId)
            
            let myFriendIds = Set(myFriends.map { $0.id })
            let theirFriendIds = Set(theirFriends.map { $0.id })
            
            return myFriendIds.intersection(theirFriendIds).count
        } catch {
            return 0
        }
    }
    
    // MARK: - 处理添加好友
    private func handleAddFriend(_ result: SearchResult) {
        guard result.friendStatus == .notFriend else { return }
        
        // 显示留言输入界面
        pendingFriendRequest = PendingFriendRequest(
            userId: result.userId,
            userName: result.name,
            source: .searchResult(result)
        )
        messageText = ""
        showMessageInput = true
    }
    
    // MARK: - 发送好友请求（带留言）
    private func sendFriendRequestWithMessage() async {
        guard let pending = pendingFriendRequest else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 发送请求（留言可以为空）
            let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
            try await FriendManager.shared.sendFriendRequest(
                from: userManager.userOpenId,
                to: pending.userId,
                message: message.isEmpty ? nil : message
            )
            
            // 关闭留言输入界面
            await MainActor.run {
                showMessageInput = false
                messageText = ""
                
                // 如果是搜索结果，更新状态
                if case .searchResult(let result) = pending.source {
                    if let index = searchResults.firstIndex(where: { $0.id == result.id }) {
                        searchResults[index] = SearchResult(
                            id: result.id,
                            name: result.name,
                            userId: result.userId,
                            userCode: result.userCode,
                            photoUrl: result.photoUrl,
                            mutualFriends: result.mutualFriends,
                            friendStatus: .requestSent
                        )
                    }
                }
                
                showSuccessMessage = true
                isLoading = false
                pendingFriendRequest = nil
            }
            
            // 刷新已发送的请求列表
            await loadSentRequests()
        } catch {
            await MainActor.run {
                errorMessage = "添加失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - 處理 Deep Link 預填邀請碼
    private func handlePrefilledInviteCode(_ code: String) async {
        do {
            guard let userId = try await FriendInviteLinkManager.shared.validateFriendInviteLink(inviteCode: code),
                  userId != userManager.userOpenId else {
                await MainActor.run {
                    errorMessage = "邀請連結已過期或無法使用"
                }
                return
            }
            let db = Firestore.firestore()
            let userDoc = try? await db.collection("users").document(userId).getDocument()
            let userData = userDoc?.data()
            let userName = (userData?["display_name"] as? String) ??
                          (userData?["alias"] as? String) ??
                          (userData?["name"] as? String) ??
                          (userData?["email"] as? String) ??
                          "未知用户"
            await MainActor.run {
                pendingFriendRequest = PendingFriendRequest(
                    userId: userId,
                    userName: userName,
                    source: .inviteLink(code)
                )
                showMessageInput = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "處理邀請連結失敗：\(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 处理邀请链接
    private func handleInviteLink() async {
        isLoading = true
        errorMessage = nil
        
        if inviteLink.isEmpty {
            do {
                let link = try await FriendInviteLinkManager.shared.generateFriendInviteLink(
                    userId: userManager.userOpenId,
                    userCode: userManager.userCode
                )
                await MainActor.run {
                    inviteLink = link
                }
            } catch {
                await MainActor.run {
                    errorMessage = "生成邀请链接失败：\(error.localizedDescription)"
                    isLoading = false
                }
                return
            }
        }
        
        let shareText = FriendInviteLinkManager.shared.generateShareText(inviteLink: inviteLink)
        await MainActor.run {
            shareItems = [shareText]
            isLoading = false
            // 延迟一点显示，确保状态更新完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showShareSheet = true
            }
        }
    }
    
    // MARK: - 处理扫描的二维码
    private func handleScannedCode(_ code: String) {
        // 先关闭扫描器
        showQRCodeScanner = false
        
        Task {
            // 解析二维码内容
            // 格式：secalender://friend/USERCODE 或 secalender://friend/USERID
            if code.hasPrefix("secalender://friend/") {
                let identifier = String(code.dropFirst("secalender://friend/".count))
                await searchByCode(identifier)
            } else {
                // 尝试直接搜索
                await MainActor.run {
                    searchInput = code
                }
                await performSearch()
            }
        }
    }
    
    private func searchByCode(_ code: String) async {
        do {
            let db = Firestore.firestore()
            var userId: String?
            
            // 先尝试作为 user_code 搜索
            let userCodeSnapshot = try await db.collection("users")
                .whereField("user_code", isEqualTo: code.uppercased())
                .getDocuments()
            
            if let doc = userCodeSnapshot.documents.first {
                userId = doc.documentID
            } else {
                // 尝试作为 userId 搜索
                let userDoc = try await db.collection("users").document(code).getDocument()
                if userDoc.exists {
                    userId = code
                }
            }
            
            guard let targetUserId = userId, targetUserId != userManager.userOpenId else {
                await MainActor.run {
                    errorMessage = "未找到该用户"
                }
                return
            }
            
            // 获取用户信息用于显示
            let userDoc = try? await db.collection("users").document(targetUserId).getDocument()
            let userData = userDoc?.data()
            let userName = (userData?["display_name"] as? String) ??
                          (userData?["alias"] as? String) ??
                          (userData?["name"] as? String) ??
                          (userData?["email"] as? String) ??
                          "未知用户"
            
            // 显示留言输入界面
            await MainActor.run {
                showQRCodeScanner = false
                pendingFriendRequest = PendingFriendRequest(
                    userId: targetUserId,
                    userName: userName,
                    source: .qrCode(code)
                )
                messageText = ""
                showMessageInput = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "添加失败：\(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 留言输入视图
    @ViewBuilder
    private var messageInputView: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let pending = pendingFriendRequest {
                    // 用户信息
                    VStack(spacing: 12) {
                        Text("發送好友請求")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("給 \(pending.userName)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                    
                    // 留言输入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text("留言（選填）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $messageText)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        
                        Text("\(messageText.count)/100")
                            .font(.caption)
                            .foregroundColor(messageText.count > 100 ? .red : .secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // 按钮
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await sendFriendRequestWithMessage()
                            }
                        } label: {
                            Text("發送")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(messageText.count > 100 ? Color.gray : Color.blue, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(messageText.count > 100 || isLoading)
                        
                        Button {
                            showMessageInput = false
                            messageText = ""
                            pendingFriendRequest = nil
                        } label: {
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMessageInput = false
                        messageText = ""
                        pendingFriendRequest = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onChange(of: messageText) { newValue in
            // 限制留言长度为100字符
            if newValue.count > 100 {
                messageText = String(newValue.prefix(100))
            }
        }
    }
    
    // MARK: - 生成自己的二维码
    private func generateMyQRCode() async {
        let content = FriendInviteLinkManager.shared.generateQRCodeContent(
            userId: userManager.userOpenId,
            userCode: userManager.userCode
        )
        
        await MainActor.run {
            qrCodeContent = content
            myQRCodeImage = QRCodeGenerator.shared.generateQRCode(from: content, size: 200)
        }
    }
    
    // MARK: - 加载已发送的请求
    private func loadSentRequests() async {
        guard !userManager.userOpenId.isEmpty else { return }
        
        isLoadingSentRequests = true
        
        do {
            let requestDocs = try await FriendManager.shared.getSentFriendRequests(for: userManager.userOpenId)
            var requests: [SentFriendRequest] = []
            
            // 获取每个请求的目标用户信息
            let db = Firestore.firestore()
            for doc in requestDocs {
                let data = doc.data()
                guard let toUserId = data["to"] as? String,
                      let statusStr = data["status"] as? String else {
                    continue
                }
                
                // 获取目标用户信息
                let userDoc = try? await db.collection("users").document(toUserId).getDocument()
                let userData = userDoc?.data()
                
                let userName = (userData?["display_name"] as? String) ??
                              (userData?["alias"] as? String) ??
                              (userData?["name"] as? String) ??
                              (userData?["email"] as? String) ??
                              "未知用户"
                let userCode = userData?["user_code"] as? String
                let photoUrl = userData?["photo_url"] as? String
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                let message = data["message"] as? String
                
                // 确定状态
                let status: SentFriendRequest.RequestStatus
                switch statusStr {
                case "pending":
                    status = .pending
                case "accepted":
                    status = .accepted
                case "rejected":
                    status = .rejected
                case "cancelled":
                    status = .cancelled
                default:
                    status = .pending
                }
                
                requests.append(SentFriendRequest(
                    id: doc.documentID,
                    requestId: doc.documentID,
                    targetUserId: toUserId,
                    targetUserName: userName,
                    targetUserCode: userCode,
                    targetPhotoUrl: photoUrl,
                    status: status,
                    createdAt: createdAt,
                    message: message
                ))
            }
            
            await MainActor.run {
                self.sentRequests = requests
                self.isLoadingSentRequests = false
            }
        } catch {
            await MainActor.run {
                print("加载已发送请求失败: \(error.localizedDescription)")
                self.isLoadingSentRequests = false
            }
        }
    }
}

// MARK: - 二维码扫描器
struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, dismiss: dismiss)
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QRCodeScannerViewController()
        controller.onCodeScanned = { code in
            context.coordinator.onCodeScanned(code)
        }
        controller.onDismiss = {
            context.coordinator.dismiss()
        }
        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .fullScreen
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    class Coordinator {
        let onCodeScanned: (String) -> Void
        let dismiss: DismissAction
        
        init(onCodeScanned: @escaping (String) -> Void, dismiss: DismissAction) {
            self.onCodeScanned = onCodeScanned
            self.dismiss = dismiss
        }
    }
}

class QRCodeScannerViewController: UIViewController {
    var onCodeScanned: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasRequestedPermission = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        // 设置导航栏
        title = "掃描二維碼"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissView)
        )
        
        // 请求相机权限
        requestCameraPermission()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert()
        @unknown default:
            showPermissionDeniedAlert()
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "需要相機權限",
            message: "請在設定中允許使用相機以掃描二維碼",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.dismissView()
        })
        alert.addAction(UIAlertAction(title: "前往設定", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        present(alert, animated: true)
    }
    
    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showErrorAlert(message: "無法訪問相機")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            showErrorAlert(message: "相機初始化失敗：\(error.localizedDescription)")
            return
        }
        
        let captureSession = AVCaptureSession()
        self.captureSession = captureSession
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            showErrorAlert(message: "無法添加相機輸入")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showErrorAlert(message: "無法添加輸出")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "錯誤",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "確定", style: .default) { [weak self] _ in
            self?.dismissView()
        })
        present(alert, animated: true)
    }
    
    @objc private func dismissView() {
        onDismiss?()
    }
}

extension QRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession?.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onCodeScanned?(stringValue)
            // 使用 onDismiss 而不是直接 dismiss，确保正确关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.onDismiss?()
            }
        }
    }
}


struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView()
            .environmentObject(FirebaseUserManager.shared)
    }
}

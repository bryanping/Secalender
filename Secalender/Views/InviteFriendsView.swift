//
//  InviteFriendsView.swift
//  Secalender
//
//

import SwiftUI
import Firebase
import FirebaseFirestore
import MessageUI
import Contacts

struct InviteFriendsView: View {
    let event: Event
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab: InviteTab = .appFriends
    @State private var selectedFriends: [String] = []
    @State private var selectedContacts: [ContactPerson] = []
    @State private var friends: [FriendEntry] = []
    @State private var contacts: [ContactPerson] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isInviting = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var inviteLink: String = ""
    @StateObject private var contactManager = ContactManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 活动信息预览
                EventPreviewCard(event: event)
                    .padding()
                
                Divider()
                
                // 标签选择器
                Picker("邀请方式", selection: $selectedTab) {
                    ForEach(InviteTab.allCases, id: \.self) { tab in
                        Label(tab.title, systemImage: tab.icon).tag(tab)
                    }
                        }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedTab) { newTab in
                    if newTab == .contacts && contacts.isEmpty {
                        Task {
                            await loadContacts()
                        }
                    }
                }
                
                // 搜索栏（仅通讯录显示）
                if selectedTab == .contacts {
                            HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("搜索联系人", text: $searchText)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // 内容区域
                if isLoading {
                    ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    contentView
                }
                
                // 底部操作区域
                bottomActionBar
            }
            .navigationTitle("邀请好友")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .appFriends:
            appFriendsView
        case .contacts:
            contactsView
        case .shareLink:
            shareLinkView
        }
    }
    
    private var appFriendsView: some View {
        Group {
            if friends.isEmpty {
                emptyStateView(
                    icon: "person.3",
                    title: "暂无好友",
                    message: "添加好友后才能邀请参加活动"
                )
                } else {
                    List {
                        ForEach(friends, id: \.id) { friend in
                            FriendSelectionRow(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id),
                                onToggle: {
                                    if selectedFriends.contains(friend.id) {
                                        selectedFriends.removeAll { $0 == friend.id }
                                    } else {
                                        selectedFriends.append(friend.id)
                                    }
                                }
                            )
                        }
                    }
                }
        }
    }
    
    private var contactsView: some View {
        Group {
            if contacts.isEmpty {
                emptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "暂无联系人",
                    message: "请允许访问通讯录以邀请联系人"
                )
            } else {
                let filteredContacts = searchText.isEmpty ? contacts : contactManager.searchContacts(searchText, in: contacts)
                
                List {
                    ForEach(filteredContacts, id: \.id) { contact in
                        ContactSelectionRow(
                            contact: contact,
                            isSelected: selectedContacts.contains(where: { $0.id == contact.id }),
                            onToggle: {
                                if let index = selectedContacts.firstIndex(where: { $0.id == contact.id }) {
                                    selectedContacts.remove(at: index)
                                } else {
                                    selectedContacts.append(contact)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var shareLinkView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 邀请链接卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("邀请链接")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    if inviteLink.isEmpty {
                        Button(action: {
                            Task {
                                await generateInviteLink()
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("生成邀请链接")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(inviteLink)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    UIPasteboard.general.string = inviteLink
                                    showSuccessMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        showSuccessMessage = false
                                    }
                                }) {
                                    Label("复制链接", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    shareInviteLink()
                                }) {
                                    Label("分享", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // 分享方式
                VStack(alignment: .leading, spacing: 16) {
                    Text("分享方式")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ShareOptionsGrid(
                        onShare: { method in
                            shareViaMethod(method)
                        }
                    )
                }
                .padding()
            }
            .padding()
        }
    }
    
    private var bottomActionBar: some View {
                VStack(spacing: 12) {
                    if let message = errorMessage {
                        Text(message)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    if showSuccessMessage {
                        Text("邀请发送成功！")
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 16) {
                        Button("取消") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                Button(action: {
                            Task {
                                await sendInvitations()
                            }
                }) {
                    if isInviting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(buttonTitle)
                    }
                        }
                        .buttonStyle(.borderedProminent)
                .disabled(!hasSelection || isInviting)
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
            }
    
    private var buttonTitle: String {
        switch selectedTab {
        case .appFriends:
            return "发送邀请"
        case .contacts:
            return "发送邀请 (\(selectedContacts.count))"
        case .shareLink:
            return "分享链接"
        }
    }
    
    private var hasSelection: Bool {
        switch selectedTab {
        case .appFriends:
            return !selectedFriends.isEmpty
        case .contacts:
            return !selectedContacts.isEmpty
        case .shareLink:
            return !inviteLink.isEmpty
        }
    }
    
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        isLoading = true
        
        Task {
            // 加载应用内好友
            await loadFriends()
            
            // 加载通讯录联系人（如果需要）
            if selectedTab == .contacts {
                await loadContacts()
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadFriends() async {
        guard !userManager.userOpenId.isEmpty else { return }
        
        let db = Firestore.firestore()
        
        do {
        // 获取当前用户的好友列表
            let snapshot = try await db.collection("friends")
            .whereField("owner", isEqualTo: userManager.userOpenId)
                .getDocuments()
            
            guard !snapshot.documents.isEmpty else {
                await MainActor.run {
                    self.friends = []
                }
                    return
                }
                
                // 提取好友ID列表
            let friendIds = snapshot.documents.compactMap { $0["friend"] as? String }
                
            guard !friendIds.isEmpty else {
                await MainActor.run {
                    self.friends = []
                }
                            return
                        }
                        
            // 根据好友ID获取好友详细信息
            let userSnapshot = try await db.collection("users")
                .whereField("openid", in: friendIds)
                .getDocuments()
                        
            await MainActor.run {
                self.friends = userSnapshot.documents.compactMap { doc in
                            let data = doc.data()
                            return FriendEntry(
                                id: doc.documentID,
                                alias: data["alias"] as? String,
                        name: data["displayName"] as? String,
                                email: data["email"] as? String,
                        photoUrl: data["photoUrl"] as? String,
                                gender: data["gender"] as? String
                            )
                        }
                    }
        } catch {
            print("加载好友列表失败: \(error.localizedDescription)")
            await MainActor.run {
                self.friends = []
            }
        }
    }
    
    private func loadContacts() async {
        do {
            let fetchedContacts = try await contactManager.fetchContacts()
            await MainActor.run {
                self.contacts = fetchedContacts
            }
        } catch {
            print("加载通讯录失败: \(error.localizedDescription)")
            await MainActor.run {
                self.contacts = []
            }
            }
    }
    
    // MARK: - Actions
    
    private func sendInvitations() async {
        isInviting = true
        errorMessage = nil
        
        do {
            switch selectedTab {
            case .appFriends:
                guard !selectedFriends.isEmpty else { return }
            try await EventManager.shared.inviteFriendsToEvent(
                eventId: event.id ?? 0,
                friendIds: selectedFriends,
                senderId: userManager.userOpenId
            )
                
            case .contacts:
                guard !selectedContacts.isEmpty else { return }
                // 通过短信或邮件发送邀请链接
                await sendInvitesToContacts()
                return // 不显示成功消息，因为分享sheet会处理
                
            case .shareLink:
                // 分享链接已在其他地方处理
                shareInviteLink()
                return
            }
            
            await MainActor.run {
                showSuccessMessage = true
                isInviting = false
                
                // 2秒后关闭页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "邀请失败：\(error.localizedDescription)"
                isInviting = false
            }
        }
    }
    
    private func sendInvitesToContacts() async {
        // 生成邀请链接
        if inviteLink.isEmpty {
            await generateInviteLink()
}

        // 准备分享内容
        let shareText = InviteLinkManager.shared.generateShareText(event: event, inviteLink: inviteLink)
        shareItems = [shareText]
        
        await MainActor.run {
            isInviting = false
            showShareSheet = true
        }
    }
    
    private func generateInviteLink() async {
        do {
            let link = try await InviteLinkManager.shared.generateEventInviteLink(
                eventId: event.id ?? 0,
                eventTitle: event.title,
                creatorId: userManager.userOpenId
            )
            await MainActor.run {
                inviteLink = link
            }
        } catch {
            await MainActor.run {
                errorMessage = "生成邀请链接失败：\(error.localizedDescription)"
            }
        }
    }
    
    private func shareInviteLink() {
        let shareText = InviteLinkManager.shared.generateShareText(event: event, inviteLink: inviteLink)
        shareItems = [shareText]
        showShareSheet = true
    }
    
    private func shareViaMethod(_ method: ShareMethod) {
        if inviteLink.isEmpty {
            Task {
                await generateInviteLink()
                await MainActor.run {
                    shareViaMethodAfterLink(method)
                }
            }
        } else {
            shareViaMethodAfterLink(method)
        }
    }
    
    private func shareViaMethodAfterLink(_ method: ShareMethod) {
        let shareText = InviteLinkManager.shared.generateShareText(event: event, inviteLink: inviteLink)
        
        switch method {
        case .message:
            if MFMessageComposeViewController.canSendText() {
                shareItems = [shareText]
                showShareSheet = true
            }
        case .mail:
            if MFMailComposeViewController.canSendMail() {
                shareItems = [shareText]
                showShareSheet = true
            }
        case .copy:
            UIPasteboard.general.string = inviteLink
            showSuccessMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showSuccessMessage = false
            }
        case .more:
            shareItems = [shareText]
            showShareSheet = true
        }
    }
}

// MARK: - Supporting Types

enum InviteTab: String, CaseIterable {
    case appFriends = "应用好友"
    case contacts = "通讯录"
    case shareLink = "分享链接"
    
    var title: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .appFriends: return "person.2"
        case .contacts: return "person.crop.circle"
        case .shareLink: return "link"
        }
    }
}

enum ShareMethod {
    case message
    case mail
    case copy
    case more
}

// MARK: - Contact Selection Row

struct ContactSelectionRow: View {
    let contact: ContactPerson
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 头像
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(contact.displayName.prefix(1))
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                
                // 联系人信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.displayName)
                        .font(.headline)
                    if let phone = contact.primaryPhone {
                        Text(phone)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else if let email = contact.primaryEmail {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // 选择状态
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Event Preview Card

struct EventPreviewCard: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("邀请好友参加")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar")
                    Text(event.date)
                }
                .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "clock")
                    Text("\(event.startTime) - \(event.endTime)")
                }
                .foregroundColor(.gray)
                
                if !event.destination.isEmpty {
                    HStack {
                        Image(systemName: "location")
                        Text(event.destination)
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Share Options Grid

struct ShareOptionsGrid: View {
    let onShare: (ShareMethod) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ShareOptionButton(
                icon: "message.fill",
                title: "短信",
                color: .green,
                action: { onShare(.message) }
            )
            
            ShareOptionButton(
                icon: "envelope.fill",
                title: "邮件",
                color: .blue,
                action: { onShare(.mail) }
            )
            
            ShareOptionButton(
                icon: "doc.on.doc",
                title: "复制链接",
                color: .orange,
                action: { onShare(.copy) }
            )
            
            ShareOptionButton(
                icon: "square.and.arrow.up",
                title: "更多",
                color: .purple,
                action: { onShare(.more) }
            )
        }
    }
}

struct ShareOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


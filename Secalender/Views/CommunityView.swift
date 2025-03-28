import SwiftUI
import Firebase
import FirebaseFirestore

struct CommunityView: View {
    @State private var friendEmails: [String] = []
    @State private var friendEvents: [Event] = []
    @State private var newFriendEmail: String = ""
    @State private var showingAddFriendAlert = false
    @State private var currentUserOpenid: String = "current_user_openid" // 替换为当前用户ID

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("好友公开活动")) {
                    if friendEvents.isEmpty {
                        Text("暂无好友活动")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(friendEvents.sorted(by: { $0.startDate < $1.startDate })) { event in
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.headline)
                                Text("\(event.startDate, formatter: timeFormatter)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    Button("添加好友") {
                        showingAddFriendAlert = true
                    }
                }
            }
            .navigationTitle("社群互动")
            .onAppear {
                loadFriends()
            }
            .alert("添加好友", isPresented: $showingAddFriendAlert) {
                TextField("好友 Email", text: $newFriendEmail)
                Button("确认", action: addFriend)
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func loadFriends() {
        let db = Firestore.firestore()
        db.collection("friendships")
            .whereField("owner", isEqualTo: currentUserOpenid)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    self.friendEmails = documents.compactMap { $0["friend"] as? String }
                    loadFriendEvents()
                }
            }
    }

    private func loadFriendEvents() {
        let db = Firestore.firestore()
        db.collection("events")
            .whereField("openChecked", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    let allEvents = documents.compactMap { try? $0.data(as: Event.self) }
                    self.friendEvents = allEvents.filter { friendEmails.contains($0.creatorOpenid) }
                }
            }
    }

    private func addFriend() {
        guard !newFriendEmail.isEmpty else { return }
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "owner": currentUserOpenid,
            "friend": newFriendEmail
        ]
        db.collection("friendships").addDocument(data: data) { error in
            if error == nil {
                newFriendEmail = ""
                loadFriends()
            }
        }
    }
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter
}()

struct CommunityView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityView()
    }
}

//
//  Untitled.swift
//  Secalender
//
//  Created by 林平 on 2025/6/7.
//

// 好友行子视图
private struct FriendRowView: View {
    let friend: FriendEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                friendAvatar
                friendInfo
                Spacer()
                selectionIndicator
            }
        }
    }

    @ViewBuilder
    private var friendAvatar: some View {
        if let urlStr = friend.photoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderAvatar
                case .empty:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(.gray)
            .frame(width: 36, height: 36)
    }

    private var friendInfo: some View {
        VStack(alignment: .leading) {
            Text(friend.alias ?? friend.email ?? "未知")
                .font(.headline)
            
            if let email = friend.email {
                Text(email)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private var selectionIndicator: some View {
        isSelected ? Image(systemName: "checkmark").foregroundColor(.green) : nil
    }
}

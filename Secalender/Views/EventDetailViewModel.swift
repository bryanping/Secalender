import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

class EventDetailViewModel: ObservableObject {
    @Published var event: Event
    @Published var errorMessage: String? = nil // 🔸加入错误提示
    @Published var isSaving: Bool = false      // 🔸保存状态指示（可用于加载转圈）

    init(event: Event = Event()) {
        self.event = event
    }

    func loadEvent() {
        // 若未来需要从 Firestore 加载详细内容，可在此实现
    }

    /// 保存活动（支持新增与更新）
    func saveEvent(currentUserOpenId: String, completion: @escaping (Bool) -> Void) {
        isSaving = true
        errorMessage = nil

        if event.creatorOpenid.isEmpty {
            event.creatorOpenid = currentUserOpenId
        }

        let handler: (Result<Void, Error>) -> Void = { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success:
                    completion(true)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription // 🔸可绑定 UI 显示
                    print("保存失败：\(error.localizedDescription)")
                    completion(false)
                }
            }
        }
        

        if let eventID = event.id {
            EventManager.shared.updateEvent(event: event, completion: handler)
        } else {
            EventManager.shared.addEvent(event: event, completion: handler)
        }
    }
}

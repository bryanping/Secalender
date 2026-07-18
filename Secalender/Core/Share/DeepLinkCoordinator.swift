//
//  DeepLinkCoordinator.swift
//  Secalender
//
//  處理分享連結與 Deep Link 導航
//

import Foundation
import SwiftUI

/// 分享連結類型
enum DeepLinkType {
    case friendInvite(code: String)
    case eventInvite(code: String)
    case eventDirect(eventId: Int, creatorId: String?)
    // 修改内容：時事活動 — 網頁「加入 App」：secalender://addevent?title=&start=&end=&location=&notes=
    case addEvent(title: String, start: Date, end: Date, location: String?, notes: String?)
    // 修改内容：ICS 匯入 — secalender://addcalendar?url=<https ics>&title=<名稱>：開 App 檢視並選擇加入
    case addCalendar(url: URL, title: String?)
}

/// 待處理的 Deep Link 導航目標
enum PendingDeepLink {
    case addFriend(inviteCode: String)
    case eventShare(event: Event)
    case eventShareError(message: String)
    // 修改内容：時事活動 — 確認後寫入 time_items
    case addTimeItem(title: String, start: Date, end: Date, location: String?, notes: String?)
    // 修改内容：ICS 匯入 — 開啟日曆預覽選擇頁
    case importCalendar(url: URL, title: String?)
}

/// Deep Link 協調器：解析 URL 並驅動導航
@MainActor
final class DeepLinkCoordinator: ObservableObject {
    static let shared = DeepLinkCoordinator()
    
    /// 待展示的 sheet 目標（由 RootView 監聽並呈現）
    @Published var pendingLink: PendingDeepLink?
    
    private init() {}
    
    /// 解析並處理傳入的 URL
    /// - Parameter url: 來自 onOpenURL 的 URL
    /// - Returns: 是否成功解析並處理
    func handleURL(_ url: URL) -> Bool {
        guard let linkType = parseDeepLink(from: url) else {
            return false
        }
        return processDeepLink(linkType)
    }
    
    /// 解析 URL 為 DeepLinkType
    private func parseDeepLink(from url: URL) -> DeepLinkType? {
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let path = url.path
        
        // 支援 secalender:// 與 https://secalender.app
        let isSecalenderScheme = scheme == "secalender"
        let isSecalenderHost = host?.hasSuffix("secalender.app") == true
        
        guard isSecalenderScheme || isSecalenderHost else { return nil }
        
        if isSecalenderScheme {
            // secalender://friend/CODE 或 secalender://invite/CODE
            let pathComponents = path.split(separator: "/").map(String.init)
            if host == "friend", let code = pathComponents.first, !code.isEmpty {
                return .friendInvite(code: code)
            }
            if host == "invite", let code = pathComponents.first, !code.isEmpty {
                return .eventInvite(code: code)
            }
            // 修改内容：時事活動 — secalender://addevent?title=&start=&end=&location=&notes=（start/end 為 ISO8601）
            if host == "addevent" {
                let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                func val(_ n: String) -> String? { q.first(where: { $0.name == n })?.value }
                let iso = ISO8601DateFormatter()
                if let title = val("title"), !title.isEmpty,
                   let sStr = val("start"), let start = iso.date(from: sStr) {
                    let end = val("end").flatMap { iso.date(from: $0) } ?? start.addingTimeInterval(3600)
                    return .addEvent(title: title, start: start, end: end, location: val("location"), notes: val("notes"))
                }
                return nil
            }
            // 修改内容：ICS 匯入 — secalender://addcalendar?url=&title=（僅允許 https 來源）
            if host == "addcalendar" {
                let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                func val(_ n: String) -> String? { q.first(where: { $0.name == n })?.value }
                if let urlStr = val("url"), let icsURL = URL(string: urlStr), icsURL.scheme == "https" {
                    return .addCalendar(url: icsURL, title: val("title"))
                }
                return nil
            }
            if host == "event", let idStr = pathComponents.first, let eventId = Int(idStr) {
                let creatorId = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "creatorId" })?.value
                return .eventDirect(eventId: eventId, creatorId: creatorId)
            }
        } else {
            // https://secalender.app/friend/CODE 或 /invite/CODE 或 /event/ID
            let pathParts = path.split(separator: "/").map(String.init)
            if pathParts.first == "friend", let code = pathParts.dropFirst().first, !code.isEmpty {
                return .friendInvite(code: code)
            }
            if pathParts.first == "invite", let code = pathParts.dropFirst().first, !code.isEmpty {
                return .eventInvite(code: code)
            }
            if pathParts.first == "event", let idStr = pathParts.dropFirst().first, let eventId = Int(idStr) {
                let creatorId = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "creatorId" })?.value
                return .eventDirect(eventId: eventId, creatorId: creatorId)
            }
        }
        return nil
    }
    
    /// 處理解析後的 Deep Link
    private func processDeepLink(_ linkType: DeepLinkType) -> Bool {
        switch linkType {
        case .friendInvite(let code):
            pendingLink = .addFriend(inviteCode: code)
            return true
            
        case .eventInvite(let code):
            Task {
                await handleEventInviteCode(code)
            }
            return true
            
        case .eventDirect(let eventId, let creatorId):
            Task {
                await handleEventDirect(eventId: eventId, creatorId: creatorId)
            }
            return true

        case .addEvent(let title, let start, let end, let location, let notes):
            // 修改内容：時事活動 — 交由 RootView 顯示確認頁後寫入 time_items
            pendingLink = .addTimeItem(title: title, start: start, end: end, location: location, notes: notes)
            return true

        case .addCalendar(let url, let title):
            // 修改内容：ICS 匯入 — 開啟預覽選擇頁
            pendingLink = .importCalendar(url: url, title: title)
            return true
        }
    }
    
    private func handleEventInviteCode(_ code: String) async {
        do {
            guard let result = try await InviteLinkManager.shared.validateInviteLink(inviteCode: code) else {
                pendingLink = .eventShareError(message: "deeplink.invite_expired".localized())
                return
            }
            let event = await EventManager.shared.fetchEventForInvitation(
                eventId: result.eventId,
                creatorId: result.creatorId
            )
            if let event = event {
                pendingLink = .eventShare(event: event)
            } else {
                pendingLink = .eventShareError(message: "deeplink.event_not_found".localized())
            }
        } catch {
            pendingLink = .eventShareError(message: error.localizedDescription)
        }
    }
    
    private func handleEventDirect(eventId: Int, creatorId: String?) async {
        guard let creatorId = creatorId else {
            pendingLink = .eventShareError(message: "deeplink.creator_required".localized())
            return
        }
        let event = await EventManager.shared.fetchEventForInvitation(
            eventId: eventId,
            creatorId: creatorId
        )
        if let event = event {
            pendingLink = .eventShare(event: event)
        } else {
            pendingLink = .eventShareError(message: "deeplink.event_not_found".localized())
        }
    }
    
    /// 清除待處理導航（由 View 在 dismiss 時呼叫）
    func clearPendingLink() {
        pendingLink = nil
    }
}

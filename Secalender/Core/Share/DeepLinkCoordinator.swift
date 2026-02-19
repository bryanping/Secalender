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
}

/// 待處理的 Deep Link 導航目標
enum PendingDeepLink {
    case addFriend(inviteCode: String)
    case eventShare(event: Event)
    case eventShareError(message: String)
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

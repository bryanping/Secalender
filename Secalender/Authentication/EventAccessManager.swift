//
//  EventAccessManager.swift
//  Secalender
//
//  Created by 林平 on 2025/6/8.
//

import Foundation

/// 活动访问来源（记录是来自何种路径进入事件）
enum EventAccessSource {
    case direct           // 直接查看自己的活动
    case friendShared     // 好友分享给我（包含公开给好友）
    case strangerShared   // 陌生人通过链接或社群邀请
    case groupMember      // 群组成员查看群组内活动
    case adminOverride    // 管理员查看全部活动
}

/// 活动权限管理器
final class EventAccessManager {
    static let shared = EventAccessManager()
    private init() {}

    /// 判断当前用户是否可查看事件
    func canCurrentUserView(event: Event, currentUserId: String, isFriend: Bool, userRole: String = "member") -> Bool {
        if event.creatorOpenid == currentUserId {
            return true // 本人
        }
        if userRole == "admin" {
            return true // 管理员可见所有
        }
        // 这里如有外部分享表可补充
        if isFriend && event.isOpenChecked {
            return true // 好友公开活动
        }
        // 其他情况不可见
        return false
    }

    /// 判断当前用户是否可编辑事件
    func canCurrentUserEdit(event: Event, currentUserId: String, userRole: String = "member") -> Bool {
        return event.creatorOpenid == currentUserId || userRole == "admin"
    }

    /// 判断是否可删除事件
    func canCurrentUserDelete(event: Event, currentUserId: String, userRole: String = "member") -> Bool {
        return canCurrentUserEdit(event: event, currentUserId: currentUserId, userRole: userRole)
    }

    /// 根据事件内容与身份判断来源
    func determineAccessSource(event: Event, currentUserId: String, isFriend: Bool) -> EventAccessSource {
        if event.creatorOpenid == currentUserId {
            return .direct
        }
        // 如有外部分享表可补充
        if isFriend && event.isOpenChecked {
            return .friendShared
        }
        return .strangerShared
    }

    /// 过滤当前用户可见的事件（⚠️需提供是否好友判断函数）
    func filterEventsForCurrentUser(
        _ allEvents: [Event],
        currentUserOpenId: String,
        userRole: String,
        isFriend: @escaping (String) -> Bool
    ) async -> [Event] {
        var filtered: [Event] = []

        for event in allEvents {
            let friend = isFriend(event.creatorOpenid)
            if canCurrentUserView(
                event: event,
                currentUserId: currentUserOpenId,
                isFriend: friend,
                userRole: userRole
            ) {
                filtered.append(event)
            }
        }

        return filtered
    }
}

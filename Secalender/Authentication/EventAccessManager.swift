//
//  EventAccessManager.swift
//  Secalender
//
//  Created by 林平 on 2025/6/8.
//

import Foundation
import SwiftUI

/// 观看者身份类型（按优先级从高到低）
enum EventViewerRole {
    case creator                    // 创建者
    case groupAdminOrOwner          // 社群管理者（Admin/Owner）
    case sharedRecipient            // 被分享者（含邀请链接）
    case groupMember                // 社群普通成员
    case friend                     // 好友
    case stranger                   // 陌生人
}

/// 事件访问来源（用于颜色判断和权限管理）
enum EventAccessSource {
    case myOwn                      // 自己创建
    case group                      // 社群活动
    case friendOrShared             // 好友可见 / 非好友单一分享 / 邀请链接 / 个人单一分享
    
    // 兼容旧版本的访问来源（保留用于向后兼容）
    case direct                     // 直接查看自己的活动（等同于 myOwn）
    case friendShared               // 好友分享给我（包含公开给好友）（等同于 friendOrShared）
    case strangerShared             // 陌生人通过链接或社群邀请（等同于 friendOrShared）
    case groupMember                // 群组成员查看群组内活动（等同于 group）
    case adminOverride              // 管理员查看全部活动
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
    
    // MARK: - 观看者身份判断（新增功能）
    
    /// 判断当前用户对事件的观看者身份
    /// - Parameters:
    ///   - event: 事件
    ///   - currentUserId: 当前用户ID
    ///   - isFriend: 是否为好友的判断函数
    ///   - isGroupMember: 是否为社群成员的判断函数
    ///   - isGroupAdminOrOwner: 是否为社群管理员或拥有者的判断函数
    ///   - isSharedRecipient: 是否为被分享者的判断函数（异步）
    /// - Returns: 观看者身份
    func determineViewerRole(
        event: Event,
        currentUserId: String,
        isFriend: (String) -> Bool,
        isGroupMember: (String?) -> Bool,
        isGroupAdminOrOwner: (String?) -> Bool,
        isSharedRecipient: (Int, String) async -> Bool
    ) async -> EventViewerRole {
        
        // 1. 创建者（最高优先级）
        if event.creatorOpenid == currentUserId {
            return .creator
        }
        
        // 2. 社群管理者（仅当事件属于该社群且对社群公开）
        if let groupId = event.groupId,
           event.openChecked == 1,
           isGroupAdminOrOwner(groupId) {
            return .groupAdminOrOwner
        }
        
        // 3. 被分享者（含邀请链接验证通过）
        if let eventId = event.id,
           await isSharedRecipient(eventId, currentUserId) {
            return .sharedRecipient
        }
        
        // 4. 社群成员（普通成员）（仅当事件属于该社群且对社群公开）
        if let groupId = event.groupId,
           event.openChecked == 1,
           isGroupMember(groupId) {
            return .groupMember
        }
        
        // 5. 好友（仅当对好友公开）
        if event.isOpenChecked,
           isFriend(event.creatorOpenid) {
            return .friend
        }
        
        // 6. 陌生人（默认）
        return .stranger
    }
    
    /// 判断事件访问来源（用于颜色判断，新版本）
    /// - Parameters:
    ///   - event: 事件
    ///   - currentUserId: 当前用户ID
    ///   - isGroupMember: 是否为社群成员的判断函数（此参数保留用于未来扩展，当前不使用）
    /// - Returns: 访问来源
    /// 
    /// 优先级说明：
    /// 1. 社群活动（groupId != nil）- 显示蓝色，无论创建者是谁
    /// 2. 自己创建的个人活动（creatorOpenid == currentUserId 且 groupId == nil）- 显示红色
    /// 3. 好友可见 / 非好友单一分享 / 邀请链接 / 个人单一分享 - 显示绿色
    func determineAccessSourceForColor(
        event: Event,
        currentUserId: String,
        isGroupMember: (String?) -> Bool
    ) -> EventAccessSource {
        
        // 1. 社群活动（优先判断）- 行程来源为社群的，即 groupId != nil，就显示为蓝色
        // 判断标准：创建行程时选择了"由社群发布"，即事件有 groupId
        // 即使是自己创建的社群活动，也应该显示为蓝色
        if event.groupId != nil {
            return .group
        }
        
        // 2. 自己创建的个人活动（非社群活动）
        if event.creatorOpenid == currentUserId {
            return .myOwn
        }
        
        // 3. 好友可见 / 非好友单一分享 / 邀请链接 / 个人单一分享
        return .friendOrShared
    }
}

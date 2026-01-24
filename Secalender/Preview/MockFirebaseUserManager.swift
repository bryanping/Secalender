//
//  MockFirebaseUserManager.swift
//  Secalender
//
//  Created by 林平 on 2025/6/11.
//
//import SwiftUI
//import Foundation
//
//class MockFirebaseUserManager: ObservableObject {
//    static let shared = MockFirebaseUserManager()
//    
//    @Published var userOpenId: String = "GvyBJV7Q7jbVB8UtKSOqhALSxQg1"
//    @Published var displayName: String? = "林平 (預覽)"
//    @Published var alias: String? = "deamor"
//    @Published var gender: String? = "male"
//    @Published var photoUrl: String? = nil  // 你可以放Google頭像網址
//    @Published var userRole: String = "member"
//    @Published var friends: [String] = [
//        "1CfhmK1JjEm63Lzv5cDM",
//        "E92WgIZCKvXvxAdmOaC2LQ9Min2"
//    ]
//}

import Foundation
import Combine

// 修复：添加所有 FirebaseUserManager 的属性，确保类型兼容
class MockFirebaseUserManager: ObservableObject {
    static let shared = MockFirebaseUserManager()
    
    @Published var userOpenId: String = "GvyBJV7Q7jbVB8UtKSOqhALSxQg1"
    @Published var displayName: String? = "林平 (预览)"
    @Published var alias: String? = "deamor.lin@gmail.com"
    @Published var gender: String? = "male"
    @Published var photoUrl: String? = nil  // 可放头像链接
    @Published var userRole: String = "member"
    @Published var friends: [String] = [
        "v1ruqm40xfNvav1L9ZJFpqrMqS12",
        "E92WglZCKvXvxAdmOAc2LQg0Min2",
        "GvyBJV7Q7jbVB8UtKSOqhALSxQg1"
    ]
    @Published var userCode: String? = "ABC12345"  // 8位数字+大写字母ID
    @Published var region: String? = "台湾"  // 地区
    @Published var phone: String? = nil  // 手机号
    @Published var userCodeModified: Bool = false  // ID是否已修改过
    @Published var favoriteTags: [String] = []  // 喜好标签
    
    // Mock 方法（如果需要的话）
    func refresh() {
        // Mock 实现，不做任何事
    }
    
    func ensureUserIsSignedIn(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
}

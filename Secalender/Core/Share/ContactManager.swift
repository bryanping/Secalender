//
//  ContactManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import Contacts
import ContactsUI

/// 通讯录联系人模型
struct ContactPerson: Identifiable {
    let id: String
    let name: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    
    var displayName: String {
        name.isEmpty ? (phoneNumbers.first ?? emailAddresses.first ?? "未知联系人") : name
    }
    
    var primaryPhone: String? {
        phoneNumbers.first
    }
    
    var primaryEmail: String? {
        emailAddresses.first
    }
}

/// 通讯录管理器
final class ContactManager: ObservableObject {
    static let shared = ContactManager()
    private init() {}
    
    private let contactStore = CNContactStore()
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    
    /// 请求通讯录权限
    func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await contactStore.requestAccess(for: .contacts)
            } catch {
                print("请求通讯录权限失败: \(error.localizedDescription)")
                return false
            }
        default:
            return false
        }
    }
    
    /// 获取所有联系人
    func fetchContacts() async throws -> [ContactPerson] {
        guard await requestAccess() else {
            throw NSError(domain: "ContactManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "需要通讯录权限"])
        }
        
        var contacts: [ContactPerson] = []
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        try contactStore.enumerateContacts(with: request) { contact, _ in
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
            let emailAddresses = contact.emailAddresses.map { $0.value as String }
            
            // 只添加有电话号码或邮箱的联系人
            if !phoneNumbers.isEmpty || !emailAddresses.isEmpty {
                let contactPerson = ContactPerson(
                    id: contact.identifier,
                    name: name,
                    phoneNumbers: phoneNumbers,
                    emailAddresses: emailAddresses
                )
                contacts.append(contactPerson)
            }
        }
        
        // 按名称排序
        return contacts.sorted { $0.displayName < $1.displayName }
    }
    
    /// 搜索联系人
    func searchContacts(_ query: String, in contacts: [ContactPerson]) -> [ContactPerson] {
        guard !query.isEmpty else { return contacts }
        
        let lowerQuery = query.lowercased()
        return contacts.filter { contact in
            contact.displayName.lowercased().contains(lowerQuery) ||
            contact.phoneNumbers.contains { $0.contains(query) } ||
            contact.emailAddresses.contains { $0.lowercased().contains(lowerQuery) }
        }
    }
}

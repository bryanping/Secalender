//
//  AvatarUploadService.swift
//  Secalender
//
//  頭像上傳至 Firebase Storage，隔離 FirebaseStorage 依賴
//

import Foundation
import UIKit
import FirebaseStorage

enum AvatarUploadService {
    /// 上傳頭像圖片至 Storage，回傳下載 URL
    static func uploadAvatar(imageData: Data, userId: String) async throws -> String {
        guard let image = UIImage(data: imageData),
              let compressed = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "AvatarUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法處理所選圖片"])
        }
        
        let ref = Storage.storage().reference().child("avatars/\(userId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(compressed, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }
}

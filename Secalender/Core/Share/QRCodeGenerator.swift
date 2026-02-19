//
//  QRCodeGenerator.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

/// 二维码生成器
final class QRCodeGenerator {
    static let shared = QRCodeGenerator()
    private init() {}
    
    /// 生成二维码图片
    /// - Parameter string: 要编码的字符串
    /// - Parameter size: 图片尺寸（默认 200x200）
    /// - Returns: 生成的 UIImage，如果失败返回 nil
    #if canImport(UIKit)
    func generateQRCode(from string: String, size: CGFloat = 200) -> UIImage? {
        let data = string.data(using: .utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // 放大图片以获得更好的清晰度
        let transform = CGAffineTransform(scaleX: size / ciImage.extent.width, y: size / ciImage.extent.height)
        let scaledImage = ciImage.transformed(by: transform)
        
        // 转换为 UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    #else
    func generateQRCode(from string: String, size: CGFloat = 200) -> NSImage? {
        let data = string.data(using: .utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // 放大图片以获得更好的清晰度
        let transform = CGAffineTransform(scaleX: size / ciImage.extent.width, y: size / ciImage.extent.height)
        let scaledImage = ciImage.transformed(by: transform)
        
        // 转换为 NSImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
    #endif
    
    /// 生成二维码图片（SwiftUI Image）
    /// - Parameter string: 要编码的字符串
    /// - Parameter size: 图片尺寸（默认 200x200）
    /// - Returns: 生成的 Image，如果失败返回占位符
    func generateQRCodeImage(from string: String, size: CGFloat = 200) -> Image {
        #if canImport(UIKit)
        if let uiImage = generateQRCode(from: string, size: size) {
            return Image(uiImage: uiImage)
        } else {
            return Image(systemName: "qrcode")
        }
        #else
        if let nsImage = generateQRCode(from: string, size: size) {
            return Image(nsImage: nsImage)
        } else {
            return Image(systemName: "qrcode")
        }
        #endif
    }
}

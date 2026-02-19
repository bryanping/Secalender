//
//  AddressFormatter.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation

/// 地址格式化工具类
/// 用于统一处理地址显示，移除无效地址、杂乱代码、国家名称和邮政编码等信息
/// 参考：https://developers.google.com/maps/documentation/ios-sdk
struct AddressFormatter {
    
    /// 格式化地址显示（移除无效地址、杂乱代码、邮政编码和国家字样）
    /// - Parameter address: 原始地址字符串
    /// - Returns: 格式化后的地址字符串
    static func formatForDisplay(_ address: String) -> String {
        guard !address.isEmpty else { return address }
        
        var cleanedAddress = address
        
        // 移除常见的无效地址标识
        let invalidAddressPatterns = [
            #"(?i)\b(unknown|未知|未命名|unnamed|dropped\s*pin)\b"#,
            #"(?i)\b(lat|lng|latitude|longitude|坐标)[：:]\s*[\d\.]+"#,
            #"位置[：:]\s*[\d\.]+\s*,\s*[\d\.]+"#,
            #"\(null\)"#,
            #"null"#,
            #"undefined"#
        ]
        for pattern in invalidAddressPatterns {
            cleanedAddress = cleanedAddress.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 移除常见的国家名称（支持多语言）
        let countryPatterns = [
            // 中文
            #",\s*中国\s*"#, #"\s*中国\s*,"#, #"^中国\s*"#, #"\s*中国$"#,
            #",\s*中國\s*"#, #"\s*中國\s*,"#, #"^中國\s*"#, #"\s*中國$"#,
            #",\s*台湾\s*"#, #"\s*台湾\s*,"#, #"^台湾\s*"#, #"\s*台湾$"#,
            #",\s*台灣\s*"#, #"\s*台灣\s*,"#, #"^台灣\s*"#, #"\s*台灣$"#,
            // 英文
            #",\s*China\s*"#, #"\s*China\s*,"#, #"^China\s*"#, #"\s*China$"#,
            #",\s*Taiwan\s*"#, #"\s*Taiwan\s*,"#, #"^Taiwan\s*"#, #"\s*Taiwan$"#,
            #",\s*United\s+States\s*"#, #"\s*United\s+States\s*,"#,
            #",\s*USA\s*"#, #"\s*USA\s*,"#, #"^USA\s*"#, #"\s*USA$"#,
            #",\s*United\s+Kingdom\s*"#, #"\s*United\s+Kingdom\s*,"#,
            #",\s*UK\s*"#, #"\s*UK\s*,"#, #"^UK\s*"#, #"\s*UK$"#,
            // 其他常见国家
            #",\s*Japan\s*"#, #",\s*韓國\s*"#, #",\s*Korea\s*"#,
            #",\s*Singapore\s*"#, #",\s*Thailand\s*"#, #",\s*Vietnam\s*"#
        ]
        for pattern in countryPatterns {
            cleanedAddress = cleanedAddress.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 移除Google Plus Code（如"5CWQ+WXW"格式）
        let plusCodePattern = #"\b[A-Z0-9]{2,4}\+[A-Z0-9]{2,4}(?:\s*[A-Z0-9]{2,4})?\b"#
        cleanedAddress = cleanedAddress.replacingOccurrences(of: plusCodePattern, with: "", options: .regularExpression)
        
        // 移除邮政编码相关文本和标签
        let postalCodeLabelPatterns = [
            #"\s*郵遞區號[：:]\s*"#,      // 繁体中文
            #"\s*郵編[：:]\s*"#,           // 简体中文
            #"\s*郵政編碼[：:]\s*"#,       // 繁体中文
            #"\s*邮政编码[：:]\s*"#,       // 简体中文
            #"\s*Postal\s+Code[：:]\s*"#,  // 英文
            #"\s*ZIP\s+Code[：:]\s*"#,     // 英文
            #"\s*ZIP[：:]\s*"#,            // 英文
            #"\s*郵便番號[：:]\s*"#,        // 日文
            #"\s*Postcode[：:]\s*"#,       // 英文（英式）
            #"\s*CEP[：:]\s*"#             // 葡萄牙文（巴西）
        ]
        for pattern in postalCodeLabelPatterns {
            cleanedAddress = cleanedAddress.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 移除邮政编码数字（匹配各种国际格式）
        let postalCodePatterns = [
            #"\s*\(\d{3,10}(?:[- ]?\d{2,4})?\)\s*"#,           // 括号内的邮政编码
            #"\s*\b\d{3,10}(?:[- ]?\d{2,4})?\b\s*"#,            // 普通邮政编码
            #"\s*[A-Z]{1,2}\d{1,2}\s?\d[A-Z]{2}\s*"#            // 英式邮政编码（如 SW1A 1AA）
        ]
        for pattern in postalCodePatterns {
            cleanedAddress = cleanedAddress.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        
        // 移除HTML标签和特殊字符
        let htmlPattern = #"<[^>]+>"#
        cleanedAddress = cleanedAddress.replacingOccurrences(of: htmlPattern, with: "", options: .regularExpression)
        
        // 移除URL和链接
        let urlPattern = #"https?://[^\s]+"#
        cleanedAddress = cleanedAddress.replacingOccurrences(of: urlPattern, with: "", options: .regularExpression)
        
        // 移除常见的杂乱代码和特殊字符序列
        let junkPatterns = [
            #"&#\d+;"#,                    // HTML实体编码
            #"&[a-z]+;"#,                   // HTML实体（如 &nbsp;）
            #"\s*[\[\]{}()]\s*"#,           // 单独的括号
            #"\s*[|\\/]\s*"#,               // 单独的斜杠和竖线
            #"\s*[*]{2,}\s*"#,              // 多个星号
            #"\s*[-]{3,}\s*"#,              // 多个连字符
            #"\s*[=]{2,}\s*"#               // 多个等号
        ]
        for pattern in junkPatterns {
            cleanedAddress = cleanedAddress.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        
        // 清理多余的空格、换行和标点
        cleanedAddress = cleanedAddress.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleanedAddress = cleanedAddress.replacingOccurrences(of: #"\s*,\s*,\s*"#, with: ", ", options: .regularExpression) // 移除重复的逗号
        cleanedAddress = cleanedAddress.replacingOccurrences(of: #"\s*\.\s*\.\s*"#, with: ". ", options: .regularExpression) // 移除重复的句号
        cleanedAddress = cleanedAddress.trimmingCharacters(in: CharacterSet(charactersIn: " ,.-"))
        cleanedAddress = cleanedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果清理后为空或只包含无效字符，返回空字符串
        if cleanedAddress.isEmpty || cleanedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ""
        }
        
        return cleanedAddress
    }
    
    /// 验证地址是否有效
    /// - Parameter address: 地址字符串
    /// - Returns: 如果地址有效返回 true
    static func isValidAddress(_ address: String) -> Bool {
        guard !address.isEmpty else { return false }
        
        let cleaned = formatForDisplay(address)
        guard !cleaned.isEmpty else { return false }
        
        // 检查是否包含有效的地址特征（至少包含字母或常见地址字符）
        let hasValidContent = cleaned.range(of: #"[a-zA-Z\u4e00-\u9fff0-9]"#, options: .regularExpression) != nil
        
        // 排除明显的无效地址
        let invalidKeywords = ["unknown", "未知", "null", "undefined", "位置:", "lat:", "lng:"]
        let containsInvalidKeyword = invalidKeywords.contains { keyword in
            cleaned.localizedCaseInsensitiveContains(keyword)
        }
        
        return hasValidContent && !containsInvalidKeyword
    }
}

// MARK: - String Extension
extension String {
    /// 格式化地址显示（移除邮政编码和中国字样）
    /// 使用示例：`address.formattedForDisplay()`
    var formattedForDisplay: String {
        return AddressFormatter.formatForDisplay(self)
    }
}

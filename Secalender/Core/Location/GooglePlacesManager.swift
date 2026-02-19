//
//  GooglePlacesManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import CoreLocation
import GooglePlaces
import GoogleMaps

/// Google Places API 搜索结果
struct GooglePlaceResult {
    let placeID: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let types: [String]
}

/// Google Places API 搜索管理器
class GooglePlacesManager {
    static let shared = GooglePlacesManager()
    private let placesClient: GMSPlacesClient
    
    // 缓存 API Key，避免重复解析 Info.plist
    private static var cachedAPIKey: String?
    
    private init() {
        placesClient = GMSPlacesClient.shared()
    }
    
    /// 初始化 Google Places（需要在 AppDelegate 中调用）
    static func configure(apiKey: String) {
        cachedAPIKey = apiKey
        GMSPlacesClient.provideAPIKey(apiKey)
        GMSServices.provideAPIKey(apiKey)
        
        #if DEBUG
        print("Google Places API 已初始化")
        #endif
    }
    
    // 搜索任务的节流控制
    private var latestSearchTask: Task<Void, Never>?
    
    /// 搜索地点（使用 Google Places Autocomplete）
    func searchPlaces(query: String, coordinate: CLLocationCoordinate2D? = nil, completion: @escaping (Result<[GooglePlaceResult], Error>) -> Void) {
        // 取消之前的搜索任务
        latestSearchTask?.cancel()
        
        // 创建新的节流任务（300ms debounce）
        latestSearchTask = Task {
            // 等待 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            // 检查是否被取消
            guard !Task.isCancelled else { return }
            
            let filter = GMSAutocompleteFilter()
            filter.type = .noFilter // 允许所有类型
            
            // 注意：新版本的 Google Places SDK 可能不支持 bounds 参数
            // 如果需要位置偏好，可以通过其他方式实现（例如在结果中按距离排序）
            
            self.placesClient.findAutocompletePredictions(
                fromQuery: query,
                filter: filter,
                sessionToken: nil
            ) { predictions, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let predictions = predictions else {
                    completion(.success([]))
                    return
                }
                
                // 优化：只返回 predictions，不立即获取详细信息
                // 详细信息在用户选择时再获取，减少 API 请求
                // 注意：以下属性已标记为弃用，但当前 SDK 版本仍可使用
                // 未来版本可能需要迁移到 GMSAutocompleteSuggestion
                let results: [GooglePlaceResult] = predictions.prefix(10).map { prediction in
                    // 使用属性访问（即使已弃用，当前版本仍可用）
                    let rawAddress = prediction.attributedSecondaryText?.string ?? ""
                    return GooglePlaceResult(
                        placeID: prediction.placeID,
                        name: prediction.attributedPrimaryText.string,
                        address: rawAddress.formattedForDisplay,
                        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), // 临时坐标，选择时再获取
                        types: prediction.types
                    )
                }
                completion(.success(results))
            }
        }
    }
    
    /// 获取地点详细信息（优化：即使部分失败也返回成功的结果）
    func fetchPlaceDetails(placeIDs: [String], completion: @escaping (Result<[GooglePlaceResult], Error>) -> Void) {
        var results: [GooglePlaceResult] = []
        let group = DispatchGroup()
        var errors: [Error] = []
        
        for placeID in placeIDs {
            group.enter()
            let fields: GMSPlaceField = [.name, .formattedAddress, .coordinate, .placeID, .types]
            
            // 使用新的 API：fetchPlaceWithRequest
            // placeProperties 需要字符串数组，需要将 GMSPlaceField 转换为字符串
            let placeProperties = [
                "name",
                "formattedAddress",
                "location",
                "placeID",
                "types"
            ]
            let request = GMSFetchPlaceRequest(
                placeID: placeID,
                placeProperties: placeProperties,
                sessionToken: nil
            )
            placesClient.fetchPlace(with: request) { place, error in
                defer { group.leave() }
                
                if let error = error {
                    #if DEBUG
                    print("获取地点详情失败 (placeID: \(placeID)): \(error.localizedDescription)")
                    #endif
                    errors.append(error)
                    return
                }
                
                guard let place = place else {
                    #if DEBUG
                    print("获取地点详情: place 为 nil (placeID: \(placeID))")
                    #endif
                    return
                }
                
                let rawAddress = place.formattedAddress ?? ""
                let result = GooglePlaceResult(
                    placeID: place.placeID ?? "",
                    name: place.name ?? "未知地点",
                    address: rawAddress.formattedForDisplay,
                    coordinate: place.coordinate,
                    types: place.types ?? []
                )
                results.append(result)
            }
        }
        
        group.notify(queue: .main) {
            // 即使部分失败，只要有成功的结果就返回成功
            if results.isEmpty {
                // 全部失败才返回错误
                let finalError = errors.first ?? NSError(domain: "GooglePlacesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "所有地点详情获取失败"])
                completion(.failure(finalError))
            } else {
                // 有成功结果就返回，即使有部分失败
                if !errors.isEmpty {
                    #if DEBUG
                    print("获取地点详情: \(results.count) 个成功，\(errors.count) 个失败")
                    #endif
                }
                completion(.success(results))
            }
        }
    }
    
    /// 获取地点详细信息（通过 placeID）
    func getPlaceDetails(placeID: String, completion: @escaping (Result<GooglePlaceResult, Error>) -> Void) {
        let fields: GMSPlaceField = [.name, .formattedAddress, .coordinate, .placeID, .types]
        
        // 使用新的 API：fetchPlaceWithRequest
        // placeProperties 需要字符串数组，需要将 GMSPlaceField 转换为字符串
        let placeProperties = [
            "name",
            "formattedAddress",
            "location",
            "placeID",
            "types"
        ]
        let request = GMSFetchPlaceRequest(
            placeID: placeID,
            placeProperties: placeProperties,
            sessionToken: nil
        )
        placesClient.fetchPlace(with: request) { place, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let place = place else {
                completion(.failure(NSError(domain: "GooglePlacesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取地点信息"])))
                return
            }
            
            let rawAddress = place.formattedAddress ?? ""
            let result = GooglePlaceResult(
                placeID: place.placeID ?? "",
                name: place.name ?? "未知地点",
                address: rawAddress.formattedForDisplay,
                coordinate: place.coordinate,
                types: place.types ?? []
            )
            completion(.success(result))
        }
    }
    
    /// 反向地理编码（坐标转地址）
    /// 注意：由于 HTTP 请求需要特殊的 API Key 配置，这里直接使用 Geocoding API
    /// 如果遇到 REQUEST_DENIED 错误，请检查 API Key 配置：
    /// 1. 在 Google Cloud Console 中启用 Geocoding API
    /// 2. 配置 API Key 的应用限制为 iOS 应用（Bundle ID）
    /// 3. 或者移除应用限制（不推荐，仅用于测试）
    func reverseGeocode(coordinate: CLLocationCoordinate2D, completion: @escaping (Result<GooglePlaceResult?, Error>) -> Void) {
        // 直接使用 Geocoding API（移除 Nearby Search 的 HTTP 请求，避免授权问题）
        reverseGeocodeHTTP(coordinate: coordinate, completion: completion)
    }
    
    /// 使用 HTTP 请求调用 Google Geocoding API（作为备用方案）
    /// 参考：https://developers.google.com/maps/documentation/geocoding/overview
    private func reverseGeocodeHTTP(coordinate: CLLocationCoordinate2D, completion: @escaping (Result<GooglePlaceResult?, Error>) -> Void) {
        guard let apiKey = getGoogleAPIKey() else {
            completion(.failure(NSError(domain: "GooglePlacesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未配置 Google API Key"])))
            return
        }
        
        // 根据系统语言设置 API 语言参数，支持多语言地址返回
        let preferredLanguage = Locale.preferredLanguages.first ?? "zh-TW"
        let languageCode = preferredLanguage.prefix(5) // 取前5个字符（如 "zh-TW", "en-US"）
        
        // 使用更广泛的 result_type 以获取更多结果
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(coordinate.latitude),\(coordinate.longitude)&key=\(apiKey)&language=\(languageCode)&result_type=street_address|route|premise|establishment|point_of_interest|neighborhood|sublocality"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "GooglePlacesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                #if DEBUG
                print("Geocoding API 网络错误: \(error.localizedDescription)")
                #endif
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                #if DEBUG
                print("Geocoding API: 无数据返回")
                #endif
                completion(.success(nil))
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                #if DEBUG
                print("Geocoding API: JSON 解析失败")
                #endif
                completion(.success(nil))
                return
            }
            
            // 检查 API 错误
            if let status = json["status"] as? String, status != "OK" {
                let errorMessage = json["error_message"] as? String ?? "未知错误"
                #if DEBUG
                print("Geocoding API 错误状态: \(status), 错误信息: \(errorMessage)")
                if status == "REQUEST_DENIED" {
                    print("⚠️ API Key 授权错误！")
                    print("请检查以下配置：")
                    print("1. 在 Google Cloud Console 中启用 Geocoding API")
                    print("2. 配置 API Key 的应用限制为 iOS 应用（Bundle ID）")
                    print("3. 或者暂时移除应用限制（仅用于测试）")
                    print("4. 等待几分钟让配置生效，然后重新启动应用")
                }
                #endif
                completion(.failure(NSError(domain: "GooglePlacesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geocoding API 错误: \(status) - \(errorMessage)"])))
                return
            }
            
            guard let results = json["results"] as? [[String: Any]] else {
                #if DEBUG
                print("Geocoding API: 未找到结果")
                #endif
                completion(.success(nil))
                return
            }
            
            // 智能选择最佳结果（优先选择有名称的地点）
            var bestResult: [String: Any]?
            var bestScore = 0
            
            for result in results {
                var score = 0
                let types = result["types"] as? [String] ?? []
                
                // 优先选择有具体名称的地点
                if let name = result["name"] as? String, !name.isEmpty,
                   name != result["formatted_address"] as? String,
                   !name.localizedCaseInsensitiveContains("Dropped Pin") {
                    score += 10
                }
                
                // 优先选择更具体的类型
                if types.contains("establishment") || types.contains("point_of_interest") {
                    score += 8
                } else if types.contains("premise") {
                    score += 6
                } else if types.contains("street_address") {
                    score += 4
                } else if types.contains("route") {
                    score += 2
                }
                
                if score > bestScore {
                    bestScore = score
                    bestResult = result
                }
            }
            
            // 如果没有找到最佳结果，使用第一个结果
            let selectedResult = bestResult ?? results.first
            
            guard let firstResult = selectedResult else {
                completion(.success(nil))
                return
            }
            
            // 提取地点名称（优先使用 name，如果无效则从地址组件提取）
            var placeName = firstResult["name"] as? String ?? ""
            
            // 如果名称无效，尝试从地址组件提取
            if placeName.isEmpty || placeName.localizedCaseInsensitiveContains("Dropped Pin") {
                if let components = firstResult["address_components"] as? [[String: Any]] {
                    // 优先使用 premise 或 establishment 的名称
                    if let premise = components.first(where: {
                        let types = $0["types"] as? [String] ?? []
                        return types.contains("premise") || types.contains("establishment")
                    }) {
                        placeName = premise["long_name"] as? String ?? ""
                    }
                    // 如果没有 premise，使用 route 名称
                    if placeName.isEmpty, let route = components.first(where: {
                        let types = $0["types"] as? [String] ?? []
                        return types.contains("route")
                    }) {
                        placeName = route["long_name"] as? String ?? ""
                    }
                }
            }
            
            // 清理地点名称
            placeName = placeName.formattedForDisplay
            if placeName.isEmpty || placeName.localizedCaseInsensitiveContains("Dropped Pin") {
                placeName = ""
            }
            
            // 提取地址组件来构建地址（排除邮政编码和国家）
            var addressComponents: [String] = []
            if let components = firstResult["address_components"] as? [[String: Any]] {
                // 排除的类型
                let excludedTypes = ["postal_code", "postal_code_prefix", "postal_code_suffix", "country", "political"]
                
                // 按顺序提取地址组件（根据地址格式规范）
                let componentOrder: [(String, Int)] = [
                    ("street_number", 1),
                    ("route", 2),
                    ("sublocality_level_1", 3),
                    ("sublocality", 4),
                    ("neighborhood", 5),
                    ("locality", 6),
                    ("administrative_area_level_2", 7),
                    ("administrative_area_level_1", 8)
                ]
                
                // 按顺序提取组件
                for (type, _) in componentOrder.sorted(by: { $0.1 < $1.1 }) {
                    if let component = components.first(where: {
                        let types = $0["types"] as? [String] ?? []
                        return types.contains(type) && !types.contains(where: { excludedTypes.contains($0) })
                    }) {
                        if let longName = component["long_name"] as? String,
                           !longName.isEmpty,
                           AddressFormatter.isValidAddress(longName) {
                            // 避免重复添加相同的组件
                            if !addressComponents.contains(longName) {
                                addressComponents.append(longName)
                            }
                        }
                    }
                }
            }
            
            // 获取格式化地址
            var formattedAddress = firstResult["formatted_address"] as? String ?? ""
            
            // 应用地址格式化（移除国家、邮政编码等）
            formattedAddress = formattedAddress.formattedForDisplay
            
            // 构建最终地址：优先使用地址组件，否则使用格式化地址
            var finalAddress = ""
            if !addressComponents.isEmpty {
                // 根据国家/地区调整地址格式
                let country = self.extractCountry(from: firstResult)
                finalAddress = self.formatAddressComponents(addressComponents, country: country)
            } else if !formattedAddress.isEmpty {
                finalAddress = formattedAddress
            }
            
            // 如果最终地址无效，使用格式化地址
            if !AddressFormatter.isValidAddress(finalAddress) && AddressFormatter.isValidAddress(formattedAddress) {
                finalAddress = formattedAddress
            }
            
            // 如果地点名称和地址相同，清空名称避免重复
            if placeName == finalAddress {
                placeName = ""
            }
            
            // 如果名称包含在地址中，从地址中移除名称部分
            if !placeName.isEmpty && finalAddress.contains(placeName) {
                finalAddress = finalAddress.replacingOccurrences(of: placeName, with: "").trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
            }
            
            let geometry = firstResult["geometry"] as? [String: Any]
            let location = geometry?["location"] as? [String: Any]
            let lat = location?["lat"] as? Double ?? coordinate.latitude
            let lng = location?["lng"] as? Double ?? coordinate.longitude
            
            // 确保地址有效
            let cleanedAddress = AddressFormatter.isValidAddress(finalAddress) ? finalAddress : ""
            let cleanedName = AddressFormatter.isValidAddress(placeName) ? placeName : ""
            
            let result = GooglePlaceResult(
                placeID: firstResult["place_id"] as? String ?? "",
                name: cleanedName,
                address: cleanedAddress,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                types: firstResult["types"] as? [String] ?? []
            )
            
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }.resume()
    }
    
    /// 从结果中提取国家信息
    private func extractCountry(from result: [String: Any]) -> String? {
        guard let components = result["address_components"] as? [[String: Any]] else {
            return nil
        }
        
        if let countryComponent = components.first(where: {
            let types = $0["types"] as? [String] ?? []
            return types.contains("country")
        }) {
            return countryComponent["short_name"] as? String
        }
        
        return nil
    }
    
    /// 根据国家/地区格式化地址组件
    /// 参考不同国家的地址格式规范
    private func formatAddressComponents(_ components: [String], country: String?) -> String {
        guard !components.isEmpty else { return "" }
        
        // 根据国家调整地址格式
        switch country {
        case "TW", "CN", "HK", "MO": // 台湾、中国、香港、澳门
            // 中文地址格式：从大到小
            return components.joined(separator: "")
        case "JP": // 日本
            // 日文地址格式：从大到小，用空格分隔
            return components.joined(separator: " ")
        case "US", "CA": // 美国、加拿大
            // 英文地址格式：从小到大，用逗号和空格分隔
            return components.reversed().joined(separator: ", ")
        case "GB", "IE": // 英国、爱尔兰
            // 英式地址格式：从小到大，用逗号分隔
            return components.reversed().joined(separator: ", ")
        default:
            // 默认格式：用空格分隔
            return components.joined(separator: " ")
        }
    }
    
    /// 搜索附近的地点
    /// 注意：由于 HTTP 请求需要特殊的 API Key 配置，这里暂时禁用
    /// 如果遇到 REQUEST_DENIED 错误，请检查 API Key 配置：
    /// 1. 在 Google Cloud Console 中启用 Places API (New)
    /// 2. 配置 API Key 的应用限制为 iOS 应用（Bundle ID）
    /// 3. 或者移除应用限制（不推荐，仅用于测试）
    func searchNearby(coordinate: CLLocationCoordinate2D, radius: Int = 1000, completion: @escaping (Result<[GooglePlaceResult], Error>) -> Void) {
        // 暂时禁用 HTTP 请求的 Nearby Search，避免授权问题
        // 如果需要此功能，请正确配置 API Key 的应用限制
        #if DEBUG
        print("searchNearby: 功能已禁用，需要配置 API Key 的应用限制")
        print("请在 Google Cloud Console 中：")
        print("1. 启用 Places API (New)")
        print("2. 配置 API Key 的应用限制为 iOS 应用（Bundle ID）")
        print("3. 或者使用无限制的 API Key（仅用于测试）")
        #endif
        
        // 返回空结果，而不是错误，避免影响用户体验
        completion(.success([]))
    }
    
    /// 获取 Google API Key（优先使用缓存，避免重复解析）
    private func getGoogleAPIKey() -> String? {
        // 优先使用缓存的 API Key
        if let cachedKey = GooglePlacesManager.cachedAPIKey, !cachedKey.isEmpty {
            return cachedKey
        }
        
        // 如果缓存不存在，尝试从配置读取（仅初始化时使用）
        // 方法1: 从 Info.plist 读取（从 Secrets.xcconfig 传递）
        if let key = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String,
           !key.isEmpty,
           key != "$(GOOGLE_MAPS_API_KEY)" {  // 检查是否被正确替换
            GooglePlacesManager.cachedAPIKey = key
            return key
        }
        
        // 方法2: 尝试从 GoogleService-Info.plist 读取（备用）
        if let path = Bundle.main.path(forResource: "GoogleService-Info.plist", ofType: nil),
           let plist = NSDictionary(contentsOfFile: path),
           let apiKey = plist["API_KEY"] as? String,
           !apiKey.isEmpty {
            GooglePlacesManager.cachedAPIKey = apiKey
            return apiKey
        }
        
        // 方法3: 从环境变量读取（用于调试）
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"],
           !envKey.isEmpty {
            GooglePlacesManager.cachedAPIKey = envKey
            return envKey
        }
        
        #if DEBUG
        print("警告: 未找到 Google API Key")
        #endif
        
        return nil
    }
}

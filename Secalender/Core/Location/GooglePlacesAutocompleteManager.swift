//
//  GooglePlacesAutocompleteManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import CoreLocation
import GooglePlaces
import Combine

/// Google Places 自动完成建议
struct GooglePlaceAutocomplete: Identifiable {
    let id: String
    let placeID: String
    let primaryText: String
    let secondaryText: String
    let types: [String]
}

/// Google Places 自动完成管理器（替代 MKLocalSearchCompleter）
class GooglePlacesAutocompleteManager: NSObject, ObservableObject {
    private let placesClient: GMSPlacesClient
    private var currentSessionToken: GMSAutocompleteSessionToken?
    
    @Published var completions: [GooglePlaceAutocomplete] = []
    
    var region: CLLocationCoordinate2D? {
        didSet {
            // 当区域改变时，可以更新搜索范围
        }
    }
    
    override init() {
        placesClient = GMSPlacesClient.shared()
        super.init()
    }
    
    func updateQueryFragment(_ fragment: String) {
        guard !fragment.isEmpty else {
            completions = []
            return
        }
        
        let filter = GMSAutocompleteFilter()
        // 注意：filter.type 已弃用，建议使用 types，但为了兼容性暂时保留
        filter.type = .noFilter // 允许所有类型
        
        // 注意：新版本的 Google Places SDK 可能不支持 bounds 参数
        // 如果需要位置偏好，可以通过其他方式实现（例如在结果中按距离排序）
        
        // 创建新的 session token
        currentSessionToken = GMSAutocompleteSessionToken()
        
        // 注意：findAutocompletePredictions 已弃用，建议使用 fetchAutocompleteSuggestionsFromRequest
        // 但由于新 API 需要 GMSAutocompleteRequest，暂时保留旧 API
        placesClient.findAutocompletePredictions(
            fromQuery: fragment,
            filter: filter,
            sessionToken: currentSessionToken
        ) { [weak self] predictions, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    #if DEBUG
                    print("Google Places 自动完成失败: \(error.localizedDescription)")
                    #endif
                    self.completions = []
                    return
                }
                
                guard let predictions = predictions else {
                    self.completions = []
                    return
                }
                
                // 注意：attributedPrimaryText、attributedSecondaryText、placeID、types 已弃用
                // 建议使用 GMSAutocompleteSuggestion，但为了兼容性暂时保留
                self.completions = predictions.map { prediction in
                    GooglePlaceAutocomplete(
                        id: prediction.placeID,
                        placeID: prediction.placeID,
                        primaryText: prediction.attributedPrimaryText.string,
                        secondaryText: prediction.attributedSecondaryText?.string ?? "",
                        types: prediction.types
                    )
                }
            }
        }
    }
    
    /// 获取完整的地点信息（通过 placeID）
    func fetchPlaceDetails(placeID: String, completion: @escaping (Result<GooglePlaceResult, Error>) -> Void) {
        GooglePlacesManager.shared.getPlaceDetails(placeID: placeID, completion: completion)
    }
}

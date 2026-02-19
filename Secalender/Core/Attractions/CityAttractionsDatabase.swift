//
//  CityAttractionsDatabase.swift
//  Secalender
//
//  城市特色资料库管理器 - 存储基础城市特色数据，避免重复API调用
//

import Foundation
import CoreLocation

/// 城市特色数据结构
public struct CityAttraction: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let category: String  // 分类：地标、景点、美食、文化等
    public let icon: String
    public let coordinate: CLLocationCoordinate2D?
    public let popularity: Int  // 热门程度（0-100），用于排序
    public let tags: [String]  // 标签：美食、历史、自然、购物、艺术等
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        category: String,
        icon: String,
        coordinate: CLLocationCoordinate2D? = nil,
        popularity: Int = 50,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.coordinate = coordinate
        self.popularity = popularity
        self.tags = tags
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: CityAttraction, rhs: CityAttraction) -> Bool {
        lhs.id == rhs.id
    }
}

/// 城市特色资料库管理器
public class CityAttractionsDatabase {
    public static let shared = CityAttractionsDatabase()
    
    private var attractionsByCity: [String: [CityAttraction]] = [:]
    
    private init() {
        loadDefaultAttractions()
    }
    
    // MARK: - 获取城市特色
    
    /// 获取城市的周边特色
    /// - Parameters:
    ///   - city: 城市名
    ///   - country: 国家名（可选）
    /// - Returns: 周边特色列表
    public func getAttractions(for city: String, country: String? = nil) -> [CityAttraction] {
        let cityKey = normalizeCityName(city)
        return attractionsByCity[cityKey] ?? []
    }
    
    /// 根据兴趣偏好和分类筛选特色
    /// - Parameters:
    ///   - city: 城市名
    ///   - country: 国家名（可选）
    ///   - interestTags: 兴趣偏好标签（增加权重）
    ///   - sortBy: 排序方式（距离、热门、沿途）
    ///   - referenceLocation: 参考位置（用于距离排序）
    ///   - routeLocations: 路径位置列表（用于沿途排序）
    ///   - excludeAttractions: 排除的特色名称列表
    ///   - maxDistance: 最大距离（米），用于地理围栏
    ///   - routeLocations: 后续行程位置列表（用于地理围栏）
    /// - Returns: 筛选后的特色列表
    public func getFilteredAttractions(
        for city: String,
        country: String? = nil,
        interestTags: [String] = [],
        sortBy: AttractionSortType = .popularity,
        referenceLocation: CLLocation? = nil,
        routeLocations: [CLLocation] = [],
        excludeAttractions: [String] = [],
        maxDistance: Double? = nil,
        futureRouteLocations: [CLLocation] = []
    ) -> [CityAttraction] {
        var attractions = getAttractions(for: city, country: country)
        
        // 1. 排除已选择的特色
        if !excludeAttractions.isEmpty {
            attractions = attractions.filter { attraction in
                !excludeAttractions.contains { excludedName in
                    attraction.name.localizedCaseInsensitiveContains(excludedName) ||
                    excludedName.localizedCaseInsensitiveContains(attraction.name)
                }
            }
        }
        
        // 2. 地理围栏：过滤掉距离后续行程太远的特色
        if let maxDistance = maxDistance, !futureRouteLocations.isEmpty {
            attractions = attractions.filter { attraction in
                guard let attractionCoord = attraction.coordinate else { return true }
                let attractionLocation = CLLocation(
                    latitude: attractionCoord.latitude,
                    longitude: attractionCoord.longitude
                )
                
                // 检查是否在后续行程位置的合理范围内
                return futureRouteLocations.contains { routeLocation in
                    attractionLocation.distance(from: routeLocation) <= maxDistance
                }
            }
        }
        
        // 3. 根据兴趣偏好增加权重
        if !interestTags.isEmpty {
            attractions = attractions.map { attraction in
                var weightedAttraction = attraction
                let matchingTags = attraction.tags.filter { tag in
                    interestTags.contains { interestTag in
                        tag.localizedCaseInsensitiveContains(interestTag) ||
                        interestTag.localizedCaseInsensitiveContains(tag)
                    }
                }
                
                // 每匹配一个兴趣标签，增加20点权重
                let weightBoost = matchingTags.count * 20
                weightedAttraction = CityAttraction(
                    id: attraction.id,
                    name: attraction.name,
                    category: attraction.category,
                    icon: attraction.icon,
                    coordinate: attraction.coordinate,
                    popularity: min(100, attraction.popularity + weightBoost),
                    tags: attraction.tags
                )
                return weightedAttraction
            }
        }
        
        // 4. 排序
        switch sortBy {
        case .distance:
            if let referenceLocation = referenceLocation {
                attractions.sort { attraction1, attraction2 in
                    let distance1 = attraction1.coordinate.map { coord in
                        referenceLocation.distance(from: CLLocation(
                            latitude: coord.latitude,
                            longitude: coord.longitude
                        ))
                    } ?? Double.infinity
                    let distance2 = attraction2.coordinate.map { coord in
                        referenceLocation.distance(from: CLLocation(
                            latitude: coord.latitude,
                            longitude: coord.longitude
                        ))
                    } ?? Double.infinity
                    return distance1 < distance2
                }
            } else {
                // 如果没有参考位置，按热门排序
                attractions.sort { $0.popularity > $1.popularity }
            }
            
        case .popularity:
            attractions.sort { $0.popularity > $1.popularity }
            
        case .route:
            if !routeLocations.isEmpty {
                attractions.sort { attraction1, attraction2 in
                    let minDistance1 = attraction1.coordinate.map { coord in
                        let attractionLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                        return routeLocations.map { routeLoc in
                            attractionLoc.distance(from: routeLoc)
                        }.min() ?? Double.infinity
                    } ?? Double.infinity
                    
                    let minDistance2 = attraction2.coordinate.map { coord in
                        let attractionLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                        return routeLocations.map { routeLoc in
                            attractionLoc.distance(from: routeLoc)
                        }.min() ?? Double.infinity
                    } ?? Double.infinity
                    
                    return minDistance1 < minDistance2
                }
            } else {
                // 如果没有路径位置，按热门排序
                attractions.sort { $0.popularity > $1.popularity }
            }
        }
        
        return attractions
    }
    
    // MARK: - 排序类型
    
    public enum AttractionSortType {
        case distance    // 距离
        case popularity  // 热门
        case route       // 沿途
    }
    
    // MARK: - 数据管理
    
    /// 添加或更新城市特色
    public func addAttractions(_ attractions: [CityAttraction], for city: String) {
        let cityKey = normalizeCityName(city)
        attractionsByCity[cityKey] = attractions
    }
    
    /// 保存特色到缓存（未来可扩展为持久化存储）
    public func saveToCache() {
        // TODO: 实现持久化存储
    }
    
    // MARK: - 辅助方法
    
    private func normalizeCityName(_ city: String) -> String {
        // 移除空格和特殊字符，统一大小写
        return city.trimmingCharacters(in: .whitespaces).lowercased()
    }
    
    // MARK: - 默认数据加载
    
    private func loadDefaultAttractions() {
        // 加载基础城市特色数据
        // 这里使用硬编码数据，未来可以从配置文件或数据库加载
        
        // 东京
        attractionsByCity["東京"] = [
            CityAttraction(name: "淺草寺", category: "宗教", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "宗教"]),
            CityAttraction(name: "東京塔", category: "地标", icon: "binoculars.fill", popularity: 90, tags: ["地标", "观光"]),
            CityAttraction(name: "新宿御苑", category: "公园", icon: "tree.fill", popularity: 85, tags: ["自然", "休闲"]),
            CityAttraction(name: "銀座", category: "购物", icon: "bag.fill", popularity: 88, tags: ["购物", "时尚"]),
            CityAttraction(name: "澀谷", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "时尚", "文化"]),
            CityAttraction(name: "上野公園", category: "公园", icon: "tree.fill", popularity: 80, tags: ["自然", "文化", "博物馆"]),
            CityAttraction(name: "明治神宮", category: "宗教", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化", "宗教"]),
            CityAttraction(name: "築地市場", category: "美食", icon: "fork.knife", popularity: 85, tags: ["美食", "文化"])
        ]
        
        // 台北
        attractionsByCity["台北"] = [
            CityAttraction(name: "101大樓", category: "地标", icon: "binoculars.fill", popularity: 95, tags: ["地标", "观光", "购物"]),
            CityAttraction(name: "故宮博物院", category: "博物馆", icon: "building.2.fill", popularity: 90, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "西門町", category: "购物", icon: "bag.fill", popularity: 88, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "陽明山", category: "自然", icon: "tree.fill", popularity: 85, tags: ["自然", "休闲"]),
            CityAttraction(name: "淡水老街", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "美食", "历史"]),
            CityAttraction(name: "中正紀念堂", category: "文化", icon: "building.columns.fill", popularity: 80, tags: ["历史", "文化"]),
            CityAttraction(name: "士林夜市", category: "美食", icon: "fork.knife", popularity: 88, tags: ["美食", "文化"]),
            CityAttraction(name: "貓空", category: "自然", icon: "tree.fill", popularity: 75, tags: ["自然", "休闲", "文化"])
        ]
        
        // 巴黎
        attractionsByCity["巴黎"] = [
            CityAttraction(name: "艾菲爾鐵塔", category: "地标", icon: "binoculars.fill", popularity: 98, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "羅浮宮", category: "博物馆", icon: "building.2.fill", popularity: 95, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "聖母院", category: "宗教", icon: "building.columns.fill", popularity: 90, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "香榭麗舍大道", category: "购物", icon: "bag.fill", popularity: 88, tags: ["购物", "时尚", "文化"]),
            CityAttraction(name: "蒙馬特高地", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "奧賽博物館", category: "博物馆", icon: "building.2.fill", popularity: 82, tags: ["艺术", "文化"]),
            CityAttraction(name: "凡爾賽宮", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "塞納河", category: "自然", icon: "water.waves", popularity: 80, tags: ["自然", "休闲", "文化"])
        ]
        
        // 纽约
        attractionsByCity["紐約"] = [
            CityAttraction(name: "自由女神像", category: "地标", icon: "binoculars.fill", popularity: 95, tags: ["地标", "历史", "文化"]),
            CityAttraction(name: "中央公園", category: "公园", icon: "tree.fill", popularity: 90, tags: ["自然", "休闲"]),
            CityAttraction(name: "時代廣場", category: "地标", icon: "mappin.circle.fill", popularity: 92, tags: ["地标", "购物", "文化"]),
            CityAttraction(name: "大都會藝術博物館", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "布魯克林大橋", category: "地标", icon: "binoculars.fill", popularity: 85, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "帝國大廈", category: "地标", icon: "binoculars.fill", popularity: 82, tags: ["地标", "观光"]),
            CityAttraction(name: "高線公園", category: "公园", icon: "tree.fill", popularity: 80, tags: ["自然", "休闲", "艺术"]),
            CityAttraction(name: "第五大道", category: "购物", icon: "bag.fill", popularity: 88, tags: ["购物", "时尚"])
        ]
        
        // 首尔
        attractionsByCity["首爾"] = [
            CityAttraction(name: "景福宮", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化"]),
            CityAttraction(name: "明洞", category: "购物", icon: "bag.fill", popularity: 88, tags: ["购物", "美食", "时尚"]),
            CityAttraction(name: "南山塔", category: "地标", icon: "binoculars.fill", popularity: 85, tags: ["地标", "观光"]),
            CityAttraction(name: "北村韓屋村", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["历史", "文化"]),
            CityAttraction(name: "東大門", category: "购物", icon: "bag.fill", popularity: 80, tags: ["购物", "时尚"]),
            CityAttraction(name: "仁寺洞", category: "文化", icon: "mappin.circle.fill", popularity: 78, tags: ["文化", "艺术", "购物"]),
            CityAttraction(name: "弘大", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "江南", category: "购物", icon: "bag.fill", popularity: 82, tags: ["购物", "时尚", "美食"])
        ]
        
        // 京都
        attractionsByCity["京都"] = [
            CityAttraction(name: "清水寺", category: "宗教", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "宗教"]),
            CityAttraction(name: "金閣寺", category: "宗教", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "宗教"]),
            CityAttraction(name: "伏見稻荷大社", category: "宗教", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "宗教"]),
            CityAttraction(name: "嵐山", category: "自然", icon: "tree.fill", popularity: 88, tags: ["自然", "文化", "休闲"]),
            CityAttraction(name: "二條城", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "祇園", category: "文化", icon: "mappin.circle.fill", popularity: 87, tags: ["文化", "美食", "历史"]),
            CityAttraction(name: "銀閣寺", category: "宗教", icon: "building.columns.fill", popularity: 80, tags: ["历史", "文化", "宗教"]),
            CityAttraction(name: "哲學之道", category: "自然", icon: "tree.fill", popularity: 78, tags: ["自然", "休闲", "文化"])
        ]
        
        // 大阪
        attractionsByCity["大阪"] = [
            CityAttraction(name: "大阪城", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化"]),
            CityAttraction(name: "道頓堀", category: "美食", icon: "fork.knife", popularity: 92, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "心齋橋", category: "购物", icon: "bag.fill", popularity: 88, tags: ["购物", "美食", "时尚"]),
            CityAttraction(name: "環球影城", category: "娱乐", icon: "theatermasks.fill", popularity: 95, tags: ["娱乐", "观光"]),
            CityAttraction(name: "通天閣", category: "地标", icon: "binoculars.fill", popularity: 82, tags: ["地标", "观光"]),
            CityAttraction(name: "天保山", category: "自然", icon: "tree.fill", popularity: 75, tags: ["自然", "休闲"]),
            CityAttraction(name: "新世界", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "美食"]),
            CityAttraction(name: "梅田藍天大廈", category: "地标", icon: "binoculars.fill", popularity: 85, tags: ["地标", "观光"])
        ]
        
        // 伦敦
        attractionsByCity["倫敦"] = [
            CityAttraction(name: "大笨鐘", category: "地标", icon: "clock.fill", popularity: 95, tags: ["地标", "历史", "文化"]),
            CityAttraction(name: "倫敦塔橋", category: "地标", icon: "binoculars.fill", popularity: 92, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "大英博物館", category: "博物馆", icon: "building.2.fill", popularity: 90, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "白金漢宮", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化"]),
            CityAttraction(name: "西敏寺", category: "宗教", icon: "building.columns.fill", popularity: 85, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "倫敦眼", category: "地标", icon: "binoculars.fill", popularity: 87, tags: ["地标", "观光", "娱乐"]),
            CityAttraction(name: "海德公園", category: "公园", icon: "tree.fill", popularity: 80, tags: ["自然", "休闲"]),
            CityAttraction(name: "科文特花園", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "购物", "美食"])
        ]
        
        // 罗马
        attractionsByCity["羅馬"] = [
            CityAttraction(name: "鬥獸場", category: "历史", icon: "building.columns.fill", popularity: 98, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "萬神殿", category: "宗教", icon: "building.columns.fill", popularity: 90, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "許願池", category: "地标", icon: "water.waves", popularity: 88, tags: ["地标", "文化", "观光"]),
            CityAttraction(name: "梵蒂岡", category: "宗教", icon: "building.columns.fill", popularity: 95, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "西班牙廣場", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "购物", "历史"]),
            CityAttraction(name: "真理之口", category: "历史", icon: "building.columns.fill", popularity: 80, tags: ["历史", "文化"]),
            CityAttraction(name: "古羅馬廣場", category: "历史", icon: "building.columns.fill", popularity: 87, tags: ["历史", "文化"]),
            CityAttraction(name: "特雷維噴泉", category: "地标", icon: "water.waves", popularity: 82, tags: ["地标", "文化", "观光"])
        ]
        
        // 巴塞罗那
        attractionsByCity["巴塞隆納"] = [
            CityAttraction(name: "聖家堂", category: "宗教", icon: "building.columns.fill", popularity: 98, tags: ["历史", "宗教", "艺术"]),
            CityAttraction(name: "高第公園", category: "公园", icon: "tree.fill", popularity: 90, tags: ["艺术", "自然", "文化"]),
            CityAttraction(name: "米拉之家", category: "建筑", icon: "building.2.fill", popularity: 88, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "巴特羅之家", category: "建筑", icon: "building.2.fill", popularity: 85, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "蘭布拉大道", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "哥德區", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化", "购物"]),
            CityAttraction(name: "巴塞隆納海灘", category: "自然", icon: "water.waves", popularity: 80, tags: ["自然", "休闲"]),
            CityAttraction(name: "諾坎普球場", category: "体育", icon: "sportscourt.fill", popularity: 85, tags: ["体育", "文化"])
        ]
        
        // 曼谷
        attractionsByCity["曼谷"] = [
            CityAttraction(name: "大皇宮", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "宗教"]),
            CityAttraction(name: "臥佛寺", category: "宗教", icon: "building.columns.fill", popularity: 90, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "鄭王廟", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "水上市場", category: "文化", icon: "water.waves", popularity: 85, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "恰圖恰週末市集", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "四面佛", category: "宗教", icon: "building.columns.fill", popularity: 82, tags: ["宗教", "文化"]),
            CityAttraction(name: "考山路", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "暹羅廣場", category: "购物", icon: "bag.fill", popularity: 85, tags: ["购物", "时尚", "美食"])
        ]
        
        // 新加坡
        attractionsByCity["新加坡"] = [
            CityAttraction(name: "濱海灣花園", category: "公园", icon: "tree.fill", popularity: 92, tags: ["自然", "观光", "休闲"]),
            CityAttraction(name: "魚尾獅公園", category: "地标", icon: "water.waves", popularity: 95, tags: ["地标", "观光", "文化"]),
            CityAttraction(name: "聖淘沙", category: "娱乐", icon: "theatermasks.fill", popularity: 90, tags: ["娱乐", "自然", "休闲"]),
            CityAttraction(name: "環球影城", category: "娱乐", icon: "theatermasks.fill", popularity: 88, tags: ["娱乐", "观光"]),
            CityAttraction(name: "牛車水", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "小印度", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "烏節路", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "时尚"]),
            CityAttraction(name: "克拉碼頭", category: "文化", icon: "water.waves", popularity: 80, tags: ["文化", "美食", "休闲"])
        ]
        
        // 香港
        attractionsByCity["香港"] = [
            CityAttraction(name: "維多利亞港", category: "地标", icon: "water.waves", popularity: 95, tags: ["地标", "观光", "文化"]),
            CityAttraction(name: "太平山", category: "自然", icon: "tree.fill", popularity: 90, tags: ["自然", "观光", "休闲"]),
            CityAttraction(name: "迪士尼樂園", category: "娱乐", icon: "theatermasks.fill", popularity: 88, tags: ["娱乐", "观光"]),
            CityAttraction(name: "海洋公園", category: "娱乐", icon: "theatermasks.fill", popularity: 85, tags: ["娱乐", "自然"]),
            CityAttraction(name: "星光大道", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "观光"]),
            CityAttraction(name: "廟街", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "蘭桂坊", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "美食", "娱乐"]),
            CityAttraction(name: "銅鑼灣", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "时尚"])
        ]
        
        // 上海
        attractionsByCity["上海"] = [
            CityAttraction(name: "外灘", category: "地标", icon: "water.waves", popularity: 95, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "東方明珠", category: "地标", icon: "binoculars.fill", popularity: 92, tags: ["地标", "观光"]),
            CityAttraction(name: "豫園", category: "文化", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "美食"]),
            CityAttraction(name: "田子坊", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "购物", "艺术"]),
            CityAttraction(name: "南京路", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "时尚"]),
            CityAttraction(name: "新天地", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "朱家角", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "上海博物館", category: "博物馆", icon: "building.2.fill", popularity: 85, tags: ["历史", "文化", "艺术"])
        ]
        
        // 北京
        attractionsByCity["北京"] = [
            CityAttraction(name: "故宮", category: "历史", icon: "building.columns.fill", popularity: 98, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "天安門", category: "地标", icon: "building.columns.fill", popularity: 95, tags: ["地标", "历史", "文化"]),
            CityAttraction(name: "長城", category: "历史", icon: "mountain.2.fill", popularity: 98, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "天壇", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "頤和園", category: "公园", icon: "tree.fill", popularity: 90, tags: ["历史", "自然", "文化"]),
            CityAttraction(name: "圓明園", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "王府井", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "南鑼鼓巷", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "美食", "购物"])
        ]
        
        // 洛杉矶
        attractionsByCity["洛杉磯"] = [
            CityAttraction(name: "好萊塢", category: "娱乐", icon: "theatermasks.fill", popularity: 95, tags: ["娱乐", "文化", "观光"]),
            CityAttraction(name: "環球影城", category: "娱乐", icon: "theatermasks.fill", popularity: 92, tags: ["娱乐", "观光"]),
            CityAttraction(name: "聖塔莫尼卡海灘", category: "自然", icon: "water.waves", popularity: 88, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "比佛利山莊", category: "购物", icon: "bag.fill", popularity: 85, tags: ["购物", "时尚", "观光"]),
            CityAttraction(name: "格里菲斯天文台", category: "科学", icon: "moon.stars.fill", popularity: 82, tags: ["科学", "观光", "文化"]),
            CityAttraction(name: "蓋蒂中心", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["艺术", "文化"]),
            CityAttraction(name: "威尼斯海灘", category: "自然", icon: "water.waves", popularity: 78, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "迪士尼樂園", category: "娱乐", icon: "theatermasks.fill", popularity: 90, tags: ["娱乐", "观光"])
        ]
        
        // 悉尼
        attractionsByCity["悉尼"] = [
            CityAttraction(name: "悉尼歌劇院", category: "地标", icon: "building.columns.fill", popularity: 98, tags: ["地标", "艺术", "文化"]),
            CityAttraction(name: "悉尼港大橋", category: "地标", icon: "binoculars.fill", popularity: 92, tags: ["地标", "观光", "历史"]),
            CityAttraction(name: "邦迪海灘", category: "自然", icon: "water.waves", popularity: 88, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "皇家植物園", category: "公园", icon: "tree.fill", popularity: 85, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "岩石區", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化", "购物"]),
            CityAttraction(name: "達令港", category: "文化", icon: "water.waves", popularity: 80, tags: ["文化", "美食", "休闲"]),
            CityAttraction(name: "塔龍加動物園", category: "娱乐", icon: "pawprint.fill", popularity: 78, tags: ["娱乐", "自然"]),
            CityAttraction(name: "藍山", category: "自然", icon: "mountain.2.fill", popularity: 85, tags: ["自然", "休闲", "观光"])
        ]
        
        // 阿姆斯特丹
        attractionsByCity["阿姆斯特丹"] = [
            CityAttraction(name: "安妮之家", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化"]),
            CityAttraction(name: "梵谷博物館", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "運河區", category: "文化", icon: "water.waves", popularity: 92, tags: ["文化", "历史", "观光"]),
            CityAttraction(name: "紅燈區", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "观光"]),
            CityAttraction(name: "國家博物館", category: "博物馆", icon: "building.2.fill", popularity: 87, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "庫肯霍夫花園", category: "公园", icon: "tree.fill", popularity: 82, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "風車村", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["历史", "文化", "观光"]),
            CityAttraction(name: "馮德爾公園", category: "公园", icon: "tree.fill", popularity: 78, tags: ["自然", "休闲"])
        ]
        
        // 柏林
        attractionsByCity["柏林"] = [
            CityAttraction(name: "布蘭登堡門", category: "地标", icon: "building.columns.fill", popularity: 95, tags: ["地标", "历史", "文化"]),
            CityAttraction(name: "柏林圍牆", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化"]),
            CityAttraction(name: "博物館島", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "國會大廈", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化", "政治"]),
            CityAttraction(name: "東邊畫廊", category: "艺术", icon: "paintbrush.fill", popularity: 82, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "波茨坦廣場", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "购物", "美食"]),
            CityAttraction(name: "夏洛滕堡宮", category: "历史", icon: "building.columns.fill", popularity: 78, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "柏林電視塔", category: "地标", icon: "binoculars.fill", popularity: 85, tags: ["地标", "观光"])
        ]
        
        // 维也纳
        attractionsByCity["維也納"] = [
            CityAttraction(name: "美泉宮", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "聖史蒂芬大教堂", category: "宗教", icon: "building.columns.fill", popularity: 90, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "維也納國家歌劇院", category: "艺术", icon: "theatermasks.fill", popularity: 88, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "霍夫堡宮", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "貝爾維德宮", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "艺术", "文化"]),
            CityAttraction(name: "維也納藝術史博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "普拉特公園", category: "公园", icon: "tree.fill", popularity: 78, tags: ["自然", "休闲", "娱乐"]),
            CityAttraction(name: "納許市場", category: "美食", icon: "fork.knife", popularity: 85, tags: ["美食", "文化", "购物"])
        ]
        
        // 布拉格
        attractionsByCity["布拉格"] = [
            CityAttraction(name: "查理大橋", category: "地标", icon: "binoculars.fill", popularity: 95, tags: ["地标", "历史", "文化"]),
            CityAttraction(name: "布拉格城堡", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "舊城廣場", category: "文化", icon: "mappin.circle.fill", popularity: 90, tags: ["历史", "文化", "观光"]),
            CityAttraction(name: "天文鐘", category: "历史", icon: "clock.fill", popularity: 88, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "聖維特大教堂", category: "宗教", icon: "building.columns.fill", popularity: 85, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "猶太區", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化"]),
            CityAttraction(name: "佩特任山", category: "自然", icon: "mountain.2.fill", popularity: 80, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "跳舞的房子", category: "建筑", icon: "building.2.fill", popularity: 78, tags: ["艺术", "建筑", "观光"])
        ]
        
        // 伊斯坦布尔
        attractionsByCity["伊斯坦堡"] = [
            CityAttraction(name: "聖索菲亞大教堂", category: "宗教", icon: "building.columns.fill", popularity: 98, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "藍色清真寺", category: "宗教", icon: "building.columns.fill", popularity: 95, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "托普卡帕宮", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "大巴扎", category: "购物", icon: "bag.fill", popularity: 88, tags: ["购物", "文化", "美食"]),
            CityAttraction(name: "博斯普魯斯海峽", category: "自然", icon: "water.waves", popularity: 85, tags: ["自然", "观光", "文化"]),
            CityAttraction(name: "加拉塔塔", category: "地标", icon: "binoculars.fill", popularity: 82, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "地下水宮", category: "历史", icon: "building.columns.fill", popularity: 80, tags: ["历史", "文化"]),
            CityAttraction(name: "香料市場", category: "购物", icon: "bag.fill", popularity: 78, tags: ["购物", "美食", "文化"])
        ]
        
        // 广州
        attractionsByCity["廣州"] = [
            CityAttraction(name: "廣州塔", category: "地标", icon: "binoculars.fill", popularity: 95, tags: ["地标", "观光"]),
            CityAttraction(name: "珠江夜遊", category: "文化", icon: "water.waves", popularity: 90, tags: ["文化", "观光", "休闲"]),
            CityAttraction(name: "陳家祠", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "沙面", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "北京路", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "上下九", category: "购物", icon: "bag.fill", popularity: 82, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "白雲山", category: "自然", icon: "mountain.2.fill", popularity: 80, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "長隆", category: "娱乐", icon: "theatermasks.fill", popularity: 88, tags: ["娱乐", "观光"])
        ]
        
        // 深圳
        attractionsByCity["深圳"] = [
            CityAttraction(name: "世界之窗", category: "娱乐", icon: "theatermasks.fill", popularity: 88, tags: ["娱乐", "观光", "文化"]),
            CityAttraction(name: "歡樂谷", category: "娱乐", icon: "theatermasks.fill", popularity: 85, tags: ["娱乐", "观光"]),
            CityAttraction(name: "大梅沙", category: "自然", icon: "water.waves", popularity: 82, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "小梅沙", category: "自然", icon: "water.waves", popularity: 80, tags: ["自然", "休闲"]),
            CityAttraction(name: "深圳灣公園", category: "公园", icon: "tree.fill", popularity: 78, tags: ["自然", "休闲"]),
            CityAttraction(name: "華僑城", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "艺术", "观光"]),
            CityAttraction(name: "東門", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "蓮花山", category: "自然", icon: "mountain.2.fill", popularity: 75, tags: ["自然", "休闲"])
        ]
        
        // 成都
        attractionsByCity["成都"] = [
            CityAttraction(name: "大熊貓基地", category: "娱乐", icon: "pawprint.fill", popularity: 95, tags: ["娱乐", "自然", "文化"]),
            CityAttraction(name: "寬窄巷子", category: "文化", icon: "mappin.circle.fill", popularity: 92, tags: ["文化", "美食", "历史"]),
            CityAttraction(name: "錦里", category: "文化", icon: "mappin.circle.fill", popularity: 90, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "武侯祠", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化"]),
            CityAttraction(name: "杜甫草堂", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "春熙路", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "时尚"]),
            CityAttraction(name: "都江堰", category: "历史", icon: "water.waves", popularity: 90, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "青城山", category: "自然", icon: "mountain.2.fill", popularity: 85, tags: ["自然", "宗教", "文化"])
        ]
        
        // 杭州
        attractionsByCity["杭州"] = [
            CityAttraction(name: "西湖", category: "自然", icon: "water.waves", popularity: 98, tags: ["自然", "历史", "文化"]),
            CityAttraction(name: "雷峰塔", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "靈隱寺", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "三潭印月", category: "自然", icon: "water.waves", popularity: 85, tags: ["自然", "文化", "观光"]),
            CityAttraction(name: "斷橋殘雪", category: "历史", icon: "mappin.circle.fill", popularity: 87, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "河坊街", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "千島湖", category: "自然", icon: "water.waves", popularity: 80, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "宋城", category: "文化", icon: "theatermasks.fill", popularity: 85, tags: ["文化", "历史", "娱乐"])
        ]
        
        // 西安
        attractionsByCity["西安"] = [
            CityAttraction(name: "兵馬俑", category: "历史", icon: "building.columns.fill", popularity: 98, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "大雁塔", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "古城牆", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "鐘樓", category: "历史", icon: "clock.fill", popularity: 88, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "回民街", category: "美食", icon: "fork.knife", popularity: 87, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "華清宮", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "陝西歷史博物館", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "大唐不夜城", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "美食", "购物"])
        ]
        
        // 重庆
        attractionsByCity["重慶"] = [
            CityAttraction(name: "洪崖洞", category: "文化", icon: "building.columns.fill", popularity: 95, tags: ["文化", "美食", "观光"]),
            CityAttraction(name: "解放碑", category: "地标", icon: "building.columns.fill", popularity: 90, tags: ["地标", "历史", "购物"]),
            CityAttraction(name: "磁器口", category: "文化", icon: "mappin.circle.fill", popularity: 88, tags: ["文化", "美食", "历史"]),
            CityAttraction(name: "長江索道", category: "观光", icon: "binoculars.fill", popularity: 85, tags: ["观光", "文化"]),
            CityAttraction(name: "朝天門", category: "地标", icon: "water.waves", popularity: 82, tags: ["地标", "观光", "文化"]),
            CityAttraction(name: "南山", category: "自然", icon: "mountain.2.fill", popularity: 80, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "大足石刻", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "武隆", category: "自然", icon: "mountain.2.fill", popularity: 78, tags: ["自然", "观光"])
        ]
        
        // 苏州
        attractionsByCity["蘇州"] = [
            CityAttraction(name: "拙政園", category: "文化", icon: "tree.fill", popularity: 95, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "留園", category: "文化", icon: "tree.fill", popularity: 90, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "獅子林", category: "文化", icon: "tree.fill", popularity: 88, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "寒山寺", category: "宗教", icon: "building.columns.fill", popularity: 85, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "周莊", category: "文化", icon: "mappin.circle.fill", popularity: 87, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "同里", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "虎丘", category: "历史", icon: "mountain.2.fill", popularity: 80, tags: ["历史", "文化", "自然"]),
            CityAttraction(name: "平江路", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "美食", "购物"])
        ]
        
        // 武汉
        attractionsByCity["武漢"] = [
            CityAttraction(name: "黃鶴樓", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "東湖", category: "自然", icon: "water.waves", popularity: 90, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "戶部巷", category: "美食", icon: "fork.knife", popularity: 88, tags: ["美食", "文化"]),
            CityAttraction(name: "長江大橋", category: "地标", icon: "binoculars.fill", popularity: 85, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "歸元寺", category: "宗教", icon: "building.columns.fill", popularity: 82, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "楚河漢街", category: "购物", icon: "bag.fill", popularity: 80, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "晴川閣", category: "历史", icon: "building.columns.fill", popularity: 78, tags: ["历史", "文化"]),
            CityAttraction(name: "古琴台", category: "历史", icon: "building.columns.fill", popularity: 75, tags: ["历史", "文化", "艺术"])
        ]
        
        // 南京
        attractionsByCity["南京"] = [
            CityAttraction(name: "中山陵", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "夫子廟", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "美食"]),
            CityAttraction(name: "秦淮河", category: "文化", icon: "water.waves", popularity: 90, tags: ["文化", "历史", "观光"]),
            CityAttraction(name: "明孝陵", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化"]),
            CityAttraction(name: "總統府", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "玄武湖", category: "自然", icon: "water.waves", popularity: 82, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "雞鳴寺", category: "宗教", icon: "building.columns.fill", popularity: 80, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "南京博物院", category: "博物馆", icon: "building.2.fill", popularity: 87, tags: ["历史", "文化", "艺术"])
        ]
        
        // 天津
        attractionsByCity["天津"] = [
            CityAttraction(name: "古文化街", category: "文化", icon: "mappin.circle.fill", popularity: 90, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "意式風情區", category: "文化", icon: "building.columns.fill", popularity: 88, tags: ["文化", "历史", "建筑"]),
            CityAttraction(name: "天津眼", category: "地标", icon: "binoculars.fill", popularity: 85, tags: ["地标", "观光", "娱乐"]),
            CityAttraction(name: "五大道", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "海河", category: "自然", icon: "water.waves", popularity: 80, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "瓷房子", category: "建筑", icon: "building.2.fill", popularity: 78, tags: ["艺术", "建筑", "观光"]),
            CityAttraction(name: "盤山", category: "自然", icon: "mountain.2.fill", popularity: 75, tags: ["自然", "休闲"]),
            CityAttraction(name: "濱海新區", category: "观光", icon: "mappin.circle.fill", popularity: 80, tags: ["观光", "文化"])
        ]
        
        // 釜山
        attractionsByCity["釜山"] = [
            CityAttraction(name: "海雲台", category: "自然", icon: "water.waves", popularity: 92, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "甘川文化村", category: "文化", icon: "mappin.circle.fill", popularity: 90, tags: ["文化", "艺术", "观光"]),
            CityAttraction(name: "札嘎其市場", category: "美食", icon: "fork.knife", popularity: 88, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "廣安里大橋", category: "地标", icon: "binoculars.fill", popularity: 85, tags: ["地标", "观光"]),
            CityAttraction(name: "太宗台", category: "自然", icon: "mountain.2.fill", popularity: 82, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "龍頭山公園", category: "公园", icon: "tree.fill", popularity: 80, tags: ["自然", "休闲"]),
            CityAttraction(name: "釜山塔", category: "地标", icon: "binoculars.fill", popularity: 78, tags: ["地标", "观光"]),
            CityAttraction(name: "松島", category: "自然", icon: "water.waves", popularity: 75, tags: ["自然", "休闲"])
        ]
        
        // 济州岛
        attractionsByCity["濟州島"] = [
            CityAttraction(name: "漢拏山", category: "自然", icon: "mountain.2.fill", popularity: 95, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "城山日出峰", category: "自然", icon: "mountain.2.fill", popularity: 92, tags: ["自然", "观光"]),
            CityAttraction(name: "牛島", category: "自然", icon: "water.waves", popularity: 90, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "泰迪熊博物館", category: "博物馆", icon: "building.2.fill", popularity: 85, tags: ["娱乐", "文化"]),
            CityAttraction(name: "柱狀節理帶", category: "自然", icon: "water.waves", popularity: 88, tags: ["自然", "观光"]),
            CityAttraction(name: "涉地可支", category: "自然", icon: "water.waves", popularity: 82, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "中文觀光區", category: "观光", icon: "mappin.circle.fill", popularity: 80, tags: ["观光", "文化", "购物"]),
            CityAttraction(name: "濟州民俗村", category: "文化", icon: "mappin.circle.fill", popularity: 78, tags: ["文化", "历史"])
        ]
        
        // 清迈
        attractionsByCity["清邁"] = [
            CityAttraction(name: "素貼山", category: "自然", icon: "mountain.2.fill", popularity: 90, tags: ["自然", "宗教", "观光"]),
            CityAttraction(name: "雙龍寺", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "清邁古城", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "週日夜市", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "大象保護區", category: "娱乐", icon: "pawprint.fill", popularity: 85, tags: ["娱乐", "自然"]),
            CityAttraction(name: "清邁大學", category: "文化", icon: "building.2.fill", popularity: 75, tags: ["文化", "观光"]),
            CityAttraction(name: "寧曼路", category: "购物", icon: "bag.fill", popularity: 82, tags: ["购物", "美食", "时尚"]),
            CityAttraction(name: "清萊白廟", category: "宗教", icon: "building.columns.fill", popularity: 80, tags: ["历史", "宗教", "文化"])
        ]
        
        // 普吉岛
        attractionsByCity["普吉島"] = [
            CityAttraction(name: "芭東海灘", category: "自然", icon: "water.waves", popularity: 95, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "卡塔海灘", category: "自然", icon: "water.waves", popularity: 90, tags: ["自然", "休闲"]),
            CityAttraction(name: "卡倫海灘", category: "自然", icon: "water.waves", popularity: 88, tags: ["自然", "休闲"]),
            CityAttraction(name: "普吉大佛", category: "宗教", icon: "building.columns.fill", popularity: 85, tags: ["宗教", "观光"]),
            CityAttraction(name: "查龍寺", category: "宗教", icon: "building.columns.fill", popularity: 82, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "幻多奇", category: "娱乐", icon: "theatermasks.fill", popularity: 80, tags: ["娱乐", "文化"]),
            CityAttraction(name: "攀牙灣", category: "自然", icon: "water.waves", popularity: 87, tags: ["自然", "观光"]),
            CityAttraction(name: "皇帝島", category: "自然", icon: "water.waves", popularity: 85, tags: ["自然", "休闲", "观光"])
        ]
        
        // 吉隆坡
        attractionsByCity["吉隆坡"] = [
            CityAttraction(name: "雙子塔", category: "地标", icon: "binoculars.fill", popularity: 98, tags: ["地标", "观光", "购物"]),
            CityAttraction(name: "獨立廣場", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "國家清真寺", category: "宗教", icon: "building.columns.fill", popularity: 85, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "茨廠街", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "雲頂", category: "娱乐", icon: "theatermasks.fill", popularity: 90, tags: ["娱乐", "观光"]),
            CityAttraction(name: "黑風洞", category: "宗教", icon: "mountain.2.fill", popularity: 82, tags: ["宗教", "自然", "文化"]),
            CityAttraction(name: "中央市場", category: "购物", icon: "bag.fill", popularity: 80, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "吉隆坡塔", category: "地标", icon: "binoculars.fill", popularity: 85, tags: ["地标", "观光"])
        ]
        
        // 胡志明市
        attractionsByCity["胡志明市"] = [
            CityAttraction(name: "聖母大教堂", category: "宗教", icon: "building.columns.fill", popularity: 90, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "中央郵局", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "統一宮", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "范五老街", category: "文化", icon: "mappin.circle.fill", popularity: 87, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "濱城市場", category: "购物", icon: "bag.fill", popularity: 82, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "戰爭遺跡博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["历史", "文化"]),
            CityAttraction(name: "西貢河", category: "自然", icon: "water.waves", popularity: 78, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "古芝地道", category: "历史", icon: "mappin.circle.fill", popularity: 75, tags: ["历史", "文化"])
        ]
        
        // 河内
        attractionsByCity["河內"] = [
            CityAttraction(name: "還劍湖", category: "自然", icon: "water.waves", popularity: 90, tags: ["自然", "历史", "文化"]),
            CityAttraction(name: "文廟", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "宗教"]),
            CityAttraction(name: "胡志明陵", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "三十六古街", category: "文化", icon: "mappin.circle.fill", popularity: 87, tags: ["文化", "购物", "美食"]),
            CityAttraction(name: "昇龍皇城", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化"]),
            CityAttraction(name: "一柱寺", category: "宗教", icon: "building.columns.fill", popularity: 80, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "下龍灣", category: "自然", icon: "water.waves", popularity: 95, tags: ["自然", "观光"]),
            CityAttraction(name: "河內大教堂", category: "宗教", icon: "building.columns.fill", popularity: 78, tags: ["历史", "宗教", "文化"])
        ]
        
        // 峇里岛
        attractionsByCity["峇里島"] = [
            CityAttraction(name: "海神廟", category: "宗教", icon: "building.columns.fill", popularity: 95, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "烏布", category: "文化", icon: "mappin.circle.fill", popularity: 92, tags: ["文化", "艺术", "购物"]),
            CityAttraction(name: "庫塔海灘", category: "自然", icon: "water.waves", popularity: 90, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "金巴蘭海灘", category: "自然", icon: "water.waves", popularity: 88, tags: ["自然", "休闲", "美食"]),
            CityAttraction(name: "聖泉寺", category: "宗教", icon: "building.columns.fill", popularity: 85, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "梯田", category: "自然", icon: "mountain.2.fill", popularity: 87, tags: ["自然", "文化", "观光"]),
            CityAttraction(name: "猴子森林", category: "自然", icon: "pawprint.fill", popularity: 82, tags: ["自然", "娱乐"]),
            CityAttraction(name: "水明漾", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "购物", "美食"])
        ]
        
        // 马尼拉
        attractionsByCity["馬尼拉"] = [
            CityAttraction(name: "馬尼拉大教堂", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "聖地亞哥堡", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "黎剎公園", category: "公园", icon: "tree.fill", popularity: 82, tags: ["自然", "历史", "文化"]),
            CityAttraction(name: "馬尼拉灣", category: "自然", icon: "water.waves", popularity: 80, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "中國城", category: "文化", icon: "mappin.circle.fill", popularity: 78, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "國家博物館", category: "博物馆", icon: "building.2.fill", popularity: 75, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "馬卡蒂", category: "购物", icon: "bag.fill", popularity: 85, tags: ["购物", "美食", "时尚"]),
            CityAttraction(name: "百勝灘", category: "自然", icon: "water.waves", popularity: 80, tags: ["自然", "休闲", "观光"])
        ]
        
        // 长滩岛
        attractionsByCity["長灘島"] = [
            CityAttraction(name: "白沙灘", category: "自然", icon: "water.waves", popularity: 98, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "普卡海灘", category: "自然", icon: "water.waves", popularity: 90, tags: ["自然", "休闲"]),
            CityAttraction(name: "星期五海灘", category: "自然", icon: "water.waves", popularity: 88, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "水晶洞", category: "自然", icon: "mountain.2.fill", popularity: 85, tags: ["自然", "观光"]),
            CityAttraction(name: "盧霍山", category: "自然", icon: "mountain.2.fill", popularity: 82, tags: ["自然", "观光"]),
            CityAttraction(name: "跳島遊", category: "娱乐", icon: "water.waves", popularity: 87, tags: ["娱乐", "自然", "观光"]),
            CityAttraction(name: "風帆", category: "娱乐", icon: "water.waves", popularity: 85, tags: ["娱乐", "自然"]),
            CityAttraction(name: "潛水", category: "娱乐", icon: "water.waves", popularity: 80, tags: ["娱乐", "自然"])
        ]
        
        // 雅典
        attractionsByCity["雅典"] = [
            CityAttraction(name: "衛城", category: "历史", icon: "building.columns.fill", popularity: 98, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "帕德嫩神廟", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "衛城博物館", category: "博物馆", icon: "building.2.fill", popularity: 90, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "古市集", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化"]),
            CityAttraction(name: "國家考古博物館", category: "博物馆", icon: "building.2.fill", popularity: 85, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "憲法廣場", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "历史"]),
            CityAttraction(name: "普拉卡", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "利卡維多斯山", category: "自然", icon: "mountain.2.fill", popularity: 78, tags: ["自然", "休闲", "观光"])
        ]
        
        // 圣托里尼
        attractionsByCity["聖托里尼"] = [
            CityAttraction(name: "伊亞", category: "文化", icon: "mappin.circle.fill", popularity: 98, tags: ["文化", "观光", "自然"]),
            CityAttraction(name: "費拉", category: "文化", icon: "mappin.circle.fill", popularity: 95, tags: ["文化", "购物", "美食"]),
            CityAttraction(name: "紅沙灘", category: "自然", icon: "water.waves", popularity: 90, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "黑沙灘", category: "自然", icon: "water.waves", popularity: 88, tags: ["自然", "休闲"]),
            CityAttraction(name: "藍頂教堂", category: "宗教", icon: "building.columns.fill", popularity: 92, tags: ["宗教", "文化", "观光"]),
            CityAttraction(name: "火山島", category: "自然", icon: "mountain.2.fill", popularity: 85, tags: ["自然", "观光"]),
            CityAttraction(name: "古代提拉", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化"]),
            CityAttraction(name: "酒莊", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "美食"])
        ]
        
        // 慕尼黑
        attractionsByCity["慕尼黑"] = [
            CityAttraction(name: "瑪麗亞廣場", category: "文化", icon: "mappin.circle.fill", popularity: 95, tags: ["文化", "历史", "地标"]),
            CityAttraction(name: "新市政廳", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "慕尼黑啤酒節", category: "文化", icon: "fork.knife", popularity: 98, tags: ["文化", "美食", "娱乐"]),
            CityAttraction(name: "寧芬堡宮", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "英國花園", category: "公园", icon: "tree.fill", popularity: 85, tags: ["自然", "休闲"]),
            CityAttraction(name: "寶馬博物館", category: "博物馆", icon: "building.2.fill", popularity: 82, tags: ["文化", "科技"]),
            CityAttraction(name: "聖母教堂", category: "宗教", icon: "building.columns.fill", popularity: 80, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "維克圖阿連市場", category: "美食", icon: "fork.knife", popularity: 87, tags: ["美食", "文化", "购物"])
        ]
        
        // 爱丁堡
        attractionsByCity["愛丁堡"] = [
            CityAttraction(name: "愛丁堡城堡", category: "历史", icon: "building.columns.fill", popularity: 98, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "皇家一英里", category: "历史", icon: "mappin.circle.fill", popularity: 92, tags: ["历史", "文化", "购物"]),
            CityAttraction(name: "荷里路德宮", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化"]),
            CityAttraction(name: "卡爾頓山", category: "自然", icon: "mountain.2.fill", popularity: 88, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "蘇格蘭國家博物館", category: "博物馆", icon: "building.2.fill", popularity: 85, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "王子街", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "亞瑟王座", category: "自然", icon: "mountain.2.fill", popularity: 82, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "蘇格蘭威士忌體驗", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "美食"])
        ]
        
        // 米兰
        attractionsByCity["米蘭"] = [
            CityAttraction(name: "米蘭大教堂", category: "宗教", icon: "building.columns.fill", popularity: 98, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "斯卡拉歌劇院", category: "艺术", icon: "theatermasks.fill", popularity: 90, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "最後的晚餐", category: "艺术", icon: "building.2.fill", popularity: 95, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "維托里奧·埃馬努埃萊二世拱廊", category: "购物", icon: "bag.fill", popularity: 92, tags: ["购物", "时尚", "建筑"]),
            CityAttraction(name: "斯福爾扎城堡", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化"]),
            CityAttraction(name: "布雷拉美術館", category: "博物馆", icon: "building.2.fill", popularity: 85, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "納維利區", category: "文化", icon: "water.waves", popularity: 82, tags: ["文化", "美食", "休闲"]),
            CityAttraction(name: "時尚區", category: "购物", icon: "bag.fill", popularity: 90, tags: ["购物", "时尚"])
        ]
        
        // 威尼斯
        attractionsByCity["威尼斯"] = [
            CityAttraction(name: "聖馬可廣場", category: "文化", icon: "mappin.circle.fill", popularity: 98, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "聖馬可大教堂", category: "宗教", icon: "building.columns.fill", popularity: 95, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "大運河", category: "自然", icon: "water.waves", popularity: 92, tags: ["自然", "文化", "观光"]),
            CityAttraction(name: "里亞托橋", category: "地标", icon: "binoculars.fill", popularity: 90, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "總督宮", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "嘆息橋", category: "历史", icon: "binoculars.fill", popularity: 85, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "彩色島", category: "文化", icon: "mappin.circle.fill", popularity: 87, tags: ["文化", "观光"]),
            CityAttraction(name: "玻璃島", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "艺术", "购物"])
        ]
        
        // 佛罗伦萨
        attractionsByCity["佛羅倫薩"] = [
            CityAttraction(name: "聖母百花大教堂", category: "宗教", icon: "building.columns.fill", popularity: 98, tags: ["历史", "宗教", "艺术"]),
            CityAttraction(name: "烏菲茲美術館", category: "博物馆", icon: "building.2.fill", popularity: 95, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "米開朗基羅廣場", category: "文化", icon: "mappin.circle.fill", popularity: 92, tags: ["文化", "艺术", "观光"]),
            CityAttraction(name: "老橋", category: "地标", icon: "binoculars.fill", popularity: 90, tags: ["地标", "历史", "购物"]),
            CityAttraction(name: "領主廣場", category: "文化", icon: "mappin.circle.fill", popularity: 88, tags: ["文化", "历史", "艺术"]),
            CityAttraction(name: "皮蒂宮", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "學院美術館", category: "博物馆", icon: "building.2.fill", popularity: 87, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "聖十字教堂", category: "宗教", icon: "building.columns.fill", popularity: 82, tags: ["历史", "宗教", "文化"])
        ]
        
        // 马德里
        attractionsByCity["馬德里"] = [
            CityAttraction(name: "普拉多博物館", category: "博物馆", icon: "building.2.fill", popularity: 95, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "皇宮", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "太陽門", category: "地标", icon: "mappin.circle.fill", popularity: 90, tags: ["地标", "历史", "文化"]),
            CityAttraction(name: "雷蒂羅公園", category: "公园", icon: "tree.fill", popularity: 88, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "格蘭大道", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "索菲亞王后藝術中心", category: "博物馆", icon: "building.2.fill", popularity: 85, tags: ["艺术", "文化"]),
            CityAttraction(name: "馬約爾廣場", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "历史", "美食"]),
            CityAttraction(name: "聖米格爾市場", category: "美食", icon: "fork.knife", popularity: 88, tags: ["美食", "文化", "购物"])
        ]
        
        // 塞维利亚
        attractionsByCity["塞維利亞"] = [
            CityAttraction(name: "塞維利亞大教堂", category: "宗教", icon: "building.columns.fill", popularity: 95, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "阿爾卡薩宮", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "黃金塔", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "西班牙廣場", category: "文化", icon: "mappin.circle.fill", popularity: 90, tags: ["文化", "历史", "建筑"]),
            CityAttraction(name: "聖十字區", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "历史", "购物"]),
            CityAttraction(name: "鬥牛場", category: "文化", icon: "sportscourt.fill", popularity: 82, tags: ["文化", "历史"]),
            CityAttraction(name: "都市陽傘", category: "建筑", icon: "building.2.fill", popularity: 80, tags: ["建筑", "艺术", "观光"]),
            CityAttraction(name: "特里亞納", category: "文化", icon: "mappin.circle.fill", popularity: 78, tags: ["文化", "美食", "艺术"])
        ]
        
        // 里昂
        attractionsByCity["里昂"] = [
            CityAttraction(name: "富維耶聖母院", category: "宗教", icon: "building.columns.fill", popularity: 92, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "里昂老城", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "里昂大教堂", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "白萊果廣場", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "历史"]),
            CityAttraction(name: "里昂壁畫", category: "艺术", icon: "paintbrush.fill", popularity: 82, tags: ["艺术", "文化"]),
            CityAttraction(name: "古羅馬劇場", category: "历史", icon: "building.columns.fill", popularity: 80, tags: ["历史", "文化"]),
            CityAttraction(name: "里昂美食市場", category: "美食", icon: "fork.knife", popularity: 87, tags: ["美食", "文化"]),
            CityAttraction(name: "匯流博物館", category: "博物馆", icon: "building.2.fill", popularity: 78, tags: ["文化", "艺术"])
        ]
        
        // 尼斯
        attractionsByCity["尼斯"] = [
            CityAttraction(name: "天使灣", category: "自然", icon: "water.waves", popularity: 95, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "英國人散步大道", category: "文化", icon: "mappin.circle.fill", popularity: 92, tags: ["文化", "休闲", "观光"]),
            CityAttraction(name: "老城區", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "美食"]),
            CityAttraction(name: "城堡山", category: "自然", icon: "mountain.2.fill", popularity: 85, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "馬蒂斯博物館", category: "博物馆", icon: "building.2.fill", popularity: 82, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "夏加爾博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["艺术", "文化"]),
            CityAttraction(name: "俄羅斯東正教大教堂", category: "宗教", icon: "building.columns.fill", popularity: 78, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "尼斯現代藝術博物館", category: "博物馆", icon: "building.2.fill", popularity: 75, tags: ["艺术", "文化"])
        ]
        
        // 萨尔茨堡
        attractionsByCity["薩爾茨堡"] = [
            CityAttraction(name: "薩爾茨堡要塞", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "莫扎特故居", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "米拉貝爾宮", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "大教堂", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "老城區", category: "历史", icon: "building.columns.fill", popularity: 87, tags: ["历史", "文化", "购物"]),
            CityAttraction(name: "音樂節", category: "文化", icon: "theatermasks.fill", popularity: 85, tags: ["文化", "艺术", "娱乐"]),
            CityAttraction(name: "海爾布倫宮", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化"]),
            CityAttraction(name: "溫特斯山", category: "自然", icon: "mountain.2.fill", popularity: 80, tags: ["自然", "休闲", "观光"])
        ]
        
        // 鹿特丹
        attractionsByCity["鹿特丹"] = [
            CityAttraction(name: "方塊屋", category: "建筑", icon: "building.2.fill", popularity: 90, tags: ["建筑", "艺术", "观光"]),
            CityAttraction(name: "歐洲桅杆", category: "地标", icon: "binoculars.fill", popularity: 88, tags: ["地标", "观光"]),
            CityAttraction(name: "鹿特丹港", category: "文化", icon: "water.waves", popularity: 85, tags: ["文化", "观光"]),
            CityAttraction(name: "博伊曼斯博物館", category: "博物馆", icon: "building.2.fill", popularity: 82, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "市場大廳", category: "美食", icon: "fork.knife", popularity: 87, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "老港", category: "文化", icon: "water.waves", popularity: 80, tags: ["文化", "历史", "观光"]),
            CityAttraction(name: "天鵝橋", category: "地标", icon: "binoculars.fill", popularity: 78, tags: ["地标", "建筑", "观光"]),
            CityAttraction(name: "鹿特丹動物園", category: "娱乐", icon: "pawprint.fill", popularity: 75, tags: ["娱乐", "自然"])
        ]
        
        // 布鲁塞尔
        attractionsByCity["布魯塞爾"] = [
            CityAttraction(name: "大廣場", category: "文化", icon: "mappin.circle.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "尿尿小童", category: "地标", icon: "mappin.circle.fill", popularity: 92, tags: ["地标", "文化", "观光"]),
            CityAttraction(name: "原子塔", category: "地标", icon: "binoculars.fill", popularity: 90, tags: ["地标", "建筑", "观光"]),
            CityAttraction(name: "布魯塞爾大教堂", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "皇家美術館", category: "博物馆", icon: "building.2.fill", popularity: 85, tags: ["艺术", "历史", "文化"]),
            CityAttraction(name: "歐盟總部", category: "文化", icon: "building.2.fill", popularity: 82, tags: ["文化", "政治"]),
            CityAttraction(name: "聖米歇爾大教堂", category: "宗教", icon: "building.columns.fill", popularity: 80, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "巧克力博物館", category: "博物馆", icon: "building.2.fill", popularity: 87, tags: ["文化", "美食"])
        ]
        
        // 苏黎世
        attractionsByCity["蘇黎世"] = [
            CityAttraction(name: "蘇黎世湖", category: "自然", icon: "water.waves", popularity: 92, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "老城區", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "购物"]),
            CityAttraction(name: "班霍夫大街", category: "购物", icon: "bag.fill", popularity: 88, tags: ["购物", "时尚", "文化"]),
            CityAttraction(name: "蘇黎世大教堂", category: "宗教", icon: "building.columns.fill", popularity: 85, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "瑞士國家博物館", category: "博物馆", icon: "building.2.fill", popularity: 82, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "林登霍夫", category: "自然", icon: "tree.fill", popularity: 80, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "格羅斯大教堂", category: "宗教", icon: "building.columns.fill", popularity: 78, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "蘇黎世動物園", category: "娱乐", icon: "pawprint.fill", popularity: 75, tags: ["娱乐", "自然"])
        ]
        
        // 里斯本
        attractionsByCity["里斯本"] = [
            CityAttraction(name: "貝倫塔", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "發現者紀念碑", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "熱羅尼莫斯修道院", category: "宗教", icon: "building.columns.fill", popularity: 90, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "聖喬治城堡", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "阿爾法瑪區", category: "文化", icon: "mappin.circle.fill", popularity: 87, tags: ["文化", "历史", "美食"]),
            CityAttraction(name: "28路電車", category: "文化", icon: "tram.fill", popularity: 85, tags: ["文化", "观光"]),
            CityAttraction(name: "商業廣場", category: "文化", icon: "mappin.circle.fill", popularity: 82, tags: ["文化", "历史", "购物"]),
            CityAttraction(name: "國家瓷磚博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["艺术", "文化", "历史"])
        ]
        
        // 华沙
        attractionsByCity["華沙"] = [
            CityAttraction(name: "老城區", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "皇家城堡", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "華沙起義博物館", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["历史", "文化"]),
            CityAttraction(name: "科學文化宮", category: "地标", icon: "building.columns.fill", popularity: 85, tags: ["地标", "建筑", "观光"]),
            CityAttraction(name: "瓦津基公園", category: "公园", icon: "tree.fill", popularity: 82, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "肖邦博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "維拉諾夫宮", category: "历史", icon: "building.columns.fill", popularity: 78, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "猶太區", category: "历史", icon: "building.columns.fill", popularity: 75, tags: ["历史", "文化"])
        ]
        
        // 布达佩斯
        attractionsByCity["布達佩斯"] = [
            CityAttraction(name: "國會大廈", category: "历史", icon: "building.columns.fill", popularity: 98, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "鏈子橋", category: "地标", icon: "binoculars.fill", popularity: 95, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "布達城堡", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "漁人堡", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "观光"]),
            CityAttraction(name: "馬提亞教堂", category: "宗教", icon: "building.columns.fill", popularity: 88, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "塞切尼溫泉", category: "休闲", icon: "water.waves", popularity: 87, tags: ["休闲", "文化", "历史"]),
            CityAttraction(name: "英雄廣場", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "历史", "地标"]),
            CityAttraction(name: "多瑙河遊船", category: "观光", icon: "water.waves", popularity: 82, tags: ["观光", "文化", "休闲"])
        ]
        
        // 哥本哈根
        attractionsByCity["哥本哈根"] = [
            CityAttraction(name: "小美人魚", category: "地标", icon: "mappin.circle.fill", popularity: 95, tags: ["地标", "文化", "观光"]),
            CityAttraction(name: "新港", category: "文化", icon: "water.waves", popularity: 92, tags: ["文化", "历史", "观光"]),
            CityAttraction(name: "蒂沃利樂園", category: "娱乐", icon: "theatermasks.fill", popularity: 90, tags: ["娱乐", "观光"]),
            CityAttraction(name: "羅森堡宮", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "圓塔", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化", "观光"]),
            CityAttraction(name: "阿美琳堡宮", category: "历史", icon: "building.columns.fill", popularity: 82, tags: ["历史", "文化"]),
            CityAttraction(name: "國家博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "克里斯蒂安堡宮", category: "历史", icon: "building.columns.fill", popularity: 78, tags: ["历史", "文化", "政治"])
        ]
        
        // 斯德哥尔摩
        attractionsByCity["斯德哥爾摩"] = [
            CityAttraction(name: "老城區", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "皇宮", category: "历史", icon: "building.columns.fill", popularity: 92, tags: ["历史", "文化"]),
            CityAttraction(name: "瓦薩博物館", category: "博物馆", icon: "building.2.fill", popularity: 90, tags: ["历史", "文化"]),
            CityAttraction(name: "市政廳", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "斯德哥爾摩群島", category: "自然", icon: "water.waves", popularity: 85, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "諾貝爾博物館", category: "博物馆", icon: "building.2.fill", popularity: 82, tags: ["文化", "历史", "科学"]),
            CityAttraction(name: "ABBA博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["文化", "艺术", "娱乐"]),
            CityAttraction(name: "斯堪森", category: "文化", icon: "mappin.circle.fill", popularity: 78, tags: ["文化", "历史", "自然"])
        ]
        
        // 赫尔辛基
        attractionsByCity["赫爾辛基"] = [
            CityAttraction(name: "赫爾辛基大教堂", category: "宗教", icon: "building.columns.fill", popularity: 95, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "岩石教堂", category: "宗教", icon: "building.columns.fill", popularity: 92, tags: ["历史", "宗教", "建筑"]),
            CityAttraction(name: "芬蘭堡", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "議會廣場", category: "文化", icon: "mappin.circle.fill", popularity: 88, tags: ["文化", "历史"]),
            CityAttraction(name: "設計區", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "艺术", "购物"]),
            CityAttraction(name: "市場廣場", category: "美食", icon: "fork.knife", popularity: 82, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "國家博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "西貝柳斯公園", category: "公园", icon: "tree.fill", popularity: 78, tags: ["自然", "文化", "艺术"])
        ]
        
        // 奥斯陆
        attractionsByCity["奧斯陸"] = [
            CityAttraction(name: "維格蘭雕塑公園", category: "艺术", icon: "tree.fill", popularity: 92, tags: ["艺术", "文化", "自然"]),
            CityAttraction(name: "奧斯陸歌劇院", category: "艺术", icon: "theatermasks.fill", popularity: 90, tags: ["艺术", "文化", "建筑"]),
            CityAttraction(name: "維京船博物館", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["历史", "文化"]),
            CityAttraction(name: "皇宮", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化"]),
            CityAttraction(name: "阿克爾碼頭", category: "文化", icon: "water.waves", popularity: 82, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "蒙克博物館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "國家美術館", category: "博物馆", icon: "building.2.fill", popularity: 78, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "霍爾門科倫", category: "体育", icon: "sportscourt.fill", popularity: 75, tags: ["体育", "文化"])
        ]
        
        // 多伦多
        attractionsByCity["多倫多"] = [
            CityAttraction(name: "CN塔", category: "地标", icon: "binoculars.fill", popularity: 98, tags: ["地标", "观光"]),
            CityAttraction(name: "尼亞加拉瀑布", category: "自然", icon: "water.waves", popularity: 95, tags: ["自然", "观光"]),
            CityAttraction(name: "皇家安大略博物館", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "卡薩羅馬", category: "历史", icon: "building.columns.fill", popularity: 85, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "多倫多群島", category: "自然", icon: "water.waves", popularity: 82, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "聖勞倫斯市場", category: "美食", icon: "fork.knife", popularity: 80, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "古釀酒廠區", category: "文化", icon: "mappin.circle.fill", popularity: 78, tags: ["文化", "艺术", "购物"]),
            CityAttraction(name: "約克維爾", category: "购物", icon: "bag.fill", popularity: 85, tags: ["购物", "时尚", "美食"])
        ]
        
        // 温哥华
        attractionsByCity["溫哥華"] = [
            CityAttraction(name: "史丹利公園", category: "公园", icon: "tree.fill", popularity: 95, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "卡皮拉諾吊橋", category: "自然", icon: "mountain.2.fill", popularity: 92, tags: ["自然", "观光"]),
            CityAttraction(name: "格蘭維爾島", category: "文化", icon: "mappin.circle.fill", popularity: 90, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "煤氣鎮", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "购物"]),
            CityAttraction(name: "英吉利灣", category: "自然", icon: "water.waves", popularity: 85, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "溫哥華水族館", category: "娱乐", icon: "pawprint.fill", popularity: 82, tags: ["娱乐", "自然"]),
            CityAttraction(name: "科學世界", category: "科学", icon: "building.2.fill", popularity: 80, tags: ["科学", "文化", "娱乐"]),
            CityAttraction(name: "羅布森街", category: "购物", icon: "bag.fill", popularity: 78, tags: ["购物", "美食", "时尚"])
        ]
        
        // 蒙特利尔
        attractionsByCity["蒙特利爾"] = [
            CityAttraction(name: "老城區", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "聖母大教堂", category: "宗教", icon: "building.columns.fill", popularity: 92, tags: ["历史", "宗教", "文化"]),
            CityAttraction(name: "皇家山", category: "自然", icon: "mountain.2.fill", popularity: 90, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "奧林匹克公園", category: "体育", icon: "sportscourt.fill", popularity: 88, tags: ["体育", "文化", "观光"]),
            CityAttraction(name: "生物圈", category: "科学", icon: "building.2.fill", popularity: 85, tags: ["科学", "自然", "文化"]),
            CityAttraction(name: "讓塔隆市場", category: "美食", icon: "fork.knife", popularity: 87, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "地下城", category: "购物", icon: "bag.fill", popularity: 82, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "植物園", category: "自然", icon: "tree.fill", popularity: 80, tags: ["自然", "休闲", "文化"])
        ]
        
        // 芝加哥
        attractionsByCity["芝加哥"] = [
            CityAttraction(name: "千禧公園", category: "公园", icon: "tree.fill", popularity: 92, tags: ["自然", "艺术", "文化"]),
            CityAttraction(name: "雲門", category: "艺术", icon: "mappin.circle.fill", popularity: 95, tags: ["艺术", "文化", "观光"]),
            CityAttraction(name: "威利斯大廈", category: "地标", icon: "binoculars.fill", popularity: 90, tags: ["地标", "观光"]),
            CityAttraction(name: "海軍碼頭", category: "文化", icon: "water.waves", popularity: 88, tags: ["文化", "娱乐", "观光"]),
            CityAttraction(name: "藝術學院", category: "博物馆", icon: "building.2.fill", popularity: 85, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "芝加哥劇院", category: "艺术", icon: "theatermasks.fill", popularity: 82, tags: ["艺术", "文化", "娱乐"]),
            CityAttraction(name: "格蘭特公園", category: "公园", icon: "tree.fill", popularity: 80, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "密歇根大道", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "时尚"])
        ]
        
        // 旧金山
        attractionsByCity["舊金山"] = [
            CityAttraction(name: "金門大橋", category: "地标", icon: "binoculars.fill", popularity: 98, tags: ["地标", "历史", "观光"]),
            CityAttraction(name: "漁人碼頭", category: "文化", icon: "water.waves", popularity: 95, tags: ["文化", "美食", "观光"]),
            CityAttraction(name: "惡魔島", category: "历史", icon: "mappin.circle.fill", popularity: 90, tags: ["历史", "文化", "观光"]),
            CityAttraction(name: "九曲花街", category: "文化", icon: "mappin.circle.fill", popularity: 88, tags: ["文化", "观光"]),
            CityAttraction(name: "唐人街", category: "文化", icon: "mappin.circle.fill", popularity: 85, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "聯合廣場", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "美食", "文化"]),
            CityAttraction(name: "金門公園", category: "公园", icon: "tree.fill", popularity: 82, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "阿爾卡特拉斯島", category: "历史", icon: "mappin.circle.fill", popularity: 80, tags: ["历史", "文化", "观光"])
        ]
        
        // 迈阿密
        attractionsByCity["邁阿密"] = [
            CityAttraction(name: "南海灘", category: "自然", icon: "water.waves", popularity: 98, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "裝飾藝術區", category: "建筑", icon: "building.columns.fill", popularity: 92, tags: ["建筑", "艺术", "文化"]),
            CityAttraction(name: "小哈瓦那", category: "文化", icon: "mappin.circle.fill", popularity: 90, tags: ["文化", "美食", "购物"]),
            CityAttraction(name: "維茲卡亞博物館", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "比斯坎灣", category: "自然", icon: "water.waves", popularity: 85, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "設計區", category: "购物", icon: "bag.fill", popularity: 87, tags: ["购物", "时尚", "艺术"]),
            CityAttraction(name: "大沼澤地", category: "自然", icon: "tree.fill", popularity: 82, tags: ["自然", "观光"]),
            CityAttraction(name: "邁阿密動物園", category: "娱乐", icon: "pawprint.fill", popularity: 80, tags: ["娱乐", "自然"])
        ]
        
        // 西雅图
        attractionsByCity["西雅圖"] = [
            CityAttraction(name: "太空針塔", category: "地标", icon: "binoculars.fill", popularity: 95, tags: ["地标", "观光"]),
            CityAttraction(name: "派克市場", category: "美食", icon: "fork.knife", popularity: 92, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "第一家星巴克", category: "文化", icon: "mappin.circle.fill", popularity: 88, tags: ["文化", "美食"]),
            CityAttraction(name: "奇胡利玻璃花園", category: "艺术", icon: "building.2.fill", popularity: 90, tags: ["艺术", "文化", "观光"]),
            CityAttraction(name: "波音工廠", category: "科学", icon: "building.2.fill", popularity: 85, tags: ["科学", "文化", "观光"]),
            CityAttraction(name: "華盛頓大學", category: "文化", icon: "building.2.fill", popularity: 82, tags: ["文化", "建筑", "观光"]),
            CityAttraction(name: "水族館", category: "娱乐", icon: "pawprint.fill", popularity: 80, tags: ["娱乐", "自然"]),
            CityAttraction(name: "先鋒廣場", category: "历史", icon: "building.columns.fill", popularity: 78, tags: ["历史", "文化", "购物"])
        ]
        
        // 波士顿
        attractionsByCity["波士頓"] = [
            CityAttraction(name: "自由之路", category: "历史", icon: "mappin.circle.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "哈佛大學", category: "文化", icon: "building.2.fill", popularity: 92, tags: ["文化", "历史", "教育"]),
            CityAttraction(name: "麻省理工", category: "文化", icon: "building.2.fill", popularity: 90, tags: ["文化", "科学", "教育"]),
            CityAttraction(name: "昆西市場", category: "美食", icon: "fork.knife", popularity: 88, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "波士頓公園", category: "公园", icon: "tree.fill", popularity: 85, tags: ["自然", "历史", "休闲"]),
            CityAttraction(name: "新英格蘭水族館", category: "娱乐", icon: "pawprint.fill", popularity: 82, tags: ["娱乐", "自然"]),
            CityAttraction(name: "美術館", category: "博物馆", icon: "building.2.fill", popularity: 80, tags: ["艺术", "文化", "历史"]),
            CityAttraction(name: "芬威球場", category: "体育", icon: "sportscourt.fill", popularity: 78, tags: ["体育", "文化"])
        ]
        
        // 华盛顿
        attractionsByCity["華盛頓"] = [
            CityAttraction(name: "白宮", category: "历史", icon: "building.columns.fill", popularity: 98, tags: ["历史", "文化", "政治"]),
            CityAttraction(name: "林肯紀念堂", category: "历史", icon: "building.columns.fill", popularity: 95, tags: ["历史", "文化", "地标"]),
            CityAttraction(name: "華盛頓紀念碑", category: "地标", icon: "binoculars.fill", popularity: 92, tags: ["地标", "历史", "文化"]),
            CityAttraction(name: "國會大廈", category: "历史", icon: "building.columns.fill", popularity: 90, tags: ["历史", "文化", "政治"]),
            CityAttraction(name: "國家廣場", category: "文化", icon: "mappin.circle.fill", popularity: 88, tags: ["文化", "历史", "地标"]),
            CityAttraction(name: "史密森尼博物館", category: "博物馆", icon: "building.2.fill", popularity: 95, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "國家動物園", category: "娱乐", icon: "pawprint.fill", popularity: 82, tags: ["娱乐", "自然"]),
            CityAttraction(name: "喬治城", category: "文化", icon: "mappin.circle.fill", popularity: 80, tags: ["文化", "历史", "购物"])
        ]
        
        // 墨尔本
        attractionsByCity["墨爾本"] = [
            CityAttraction(name: "聯邦廣場", category: "文化", icon: "mappin.circle.fill", popularity: 90, tags: ["文化", "艺术", "建筑"]),
            CityAttraction(name: "弗林德斯街車站", category: "历史", icon: "building.columns.fill", popularity: 88, tags: ["历史", "文化", "建筑"]),
            CityAttraction(name: "皇家植物園", category: "公园", icon: "tree.fill", popularity: 85, tags: ["自然", "休闲", "文化"]),
            CityAttraction(name: "墨爾本博物館", category: "博物馆", icon: "building.2.fill", popularity: 82, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "尤里卡觀景台", category: "地标", icon: "binoculars.fill", popularity: 87, tags: ["地标", "观光"]),
            CityAttraction(name: "聖基爾達", category: "自然", icon: "water.waves", popularity: 80, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "維多利亞市場", category: "美食", icon: "fork.knife", popularity: 85, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "大洋路", category: "自然", icon: "water.waves", popularity: 92, tags: ["自然", "观光"])
        ]
        
        // 奥克兰
        attractionsByCity["奧克蘭"] = [
            CityAttraction(name: "天空塔", category: "地标", icon: "binoculars.fill", popularity: 95, tags: ["地标", "观光"]),
            CityAttraction(name: "奧克蘭博物館", category: "博物馆", icon: "building.2.fill", popularity: 88, tags: ["历史", "文化", "艺术"]),
            CityAttraction(name: "一樹山", category: "自然", icon: "mountain.2.fill", popularity: 85, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "維多利亞公園市場", category: "美食", icon: "fork.knife", popularity: 82, tags: ["美食", "文化", "购物"]),
            CityAttraction(name: "奧克蘭動物園", category: "娱乐", icon: "pawprint.fill", popularity: 80, tags: ["娱乐", "自然"]),
            CityAttraction(name: "使命灣", category: "自然", icon: "water.waves", popularity: 87, tags: ["自然", "休闲", "观光"]),
            CityAttraction(name: "奧克蘭藝術館", category: "博物馆", icon: "building.2.fill", popularity: 78, tags: ["艺术", "文化"]),
            CityAttraction(name: "懷赫科島", category: "自然", icon: "water.waves", popularity: 75, tags: ["自然", "休闲", "观光"])
        ]
        
        // 更多城市可以继续添加...
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
}

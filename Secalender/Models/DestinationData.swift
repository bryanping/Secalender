//
//  DestinationData.swift
//  Secalender
//
//  目的地数据管理 - 国家-城市映射及周边特色数据
//  未来可扩展为数据库管理，支持周边特色缓存，避免重复调用 OpenAI API
//

import Foundation

// MARK: - 简繁体转换辅助

/// 简繁体转换工具（支持所有国家和城市）
private struct ChineseConverter {
    // 国家简繁体映射
    static let countrySimplifiedToTraditional: [String: String] = [
        "中国": "中國", "日本": "日本", "韩国": "韓國", "台湾": "台灣", "泰国": "泰國",
        "新加坡": "新加坡", "马来西亚": "馬來西亞", "越南": "越南", "印尼": "印尼", "菲律宾": "菲律賓",
        "希腊": "希臘", "德国": "德國", "英国": "英國", "意大利": "義大利", "西班牙": "西班牙",
        "法国": "法國", "奥地利": "奧地利", "美国": "美國", "墨西哥": "墨西哥", "土耳其": "土耳其"
    ]
    
    // 国家英语名称映射
    static let countryEnglishNames: [String: String] = [
        "中國": "China", "日本": "Japan", "韓國": "South Korea", "台灣": "Taiwan", "泰國": "Thailand",
        "新加坡": "Singapore", "馬來西亞": "Malaysia", "越南": "Vietnam", "印尼": "Indonesia", "菲律賓": "Philippines",
        "希臘": "Greece", "德國": "Germany", "英國": "United Kingdom", "義大利": "Italy", "西班牙": "Spain",
        "法國": "France", "奧地利": "Austria", "美國": "United States", "墨西哥": "Mexico", "土耳其": "Turkey"
    ]
    
    // 城市简繁体映射（主要城市）
    static let citySimplifiedToTraditional: [String: String] = [
        // 中国城市
        "北京": "北京", "上海": "上海", "广州": "廣州", "深圳": "深圳", "成都": "成都",
        "杭州": "杭州", "西安": "西安", "重庆": "重慶", "苏州": "蘇州", "武汉": "武漢",
        "南京": "南京", "天津": "天津", "郑州": "鄭州", "长沙": "長沙", "东莞": "東莞",
        "佛山": "佛山", "宁波": "寧波", "青岛": "青島", "无锡": "無錫", "合肥": "合肥",
        "昆明": "昆明", "大连": "大連", "厦门": "廈門", "哈尔滨": "哈爾濱", "济南": "濟南",
        "福州": "福州", "温州": "溫州", "石家庄": "石家莊", "泉州": "泉州", "南宁": "南寧",
        "长春": "長春", "南昌": "南昌", "贵阳": "貴陽", "太原": "太原", "三亚": "三亞",
        "丽江": "麗江", "大理": "大理", "桂林": "桂林", "张家界": "張家界", "九寨沟": "九寨溝",
        "黄山": "黃山", "庐山": "廬山", "峨眉山": "峨眉山", "泰山": "泰山", "华山": "華山",
        // 日本城市
        "东京": "東京", "京都": "京都", "大阪": "大阪", "冲绳": "沖繩", "福冈": "福岡",
        "名古屋": "名古屋", "横滨": "橫濱", "神户": "神戶", "广岛": "廣島", "仙台": "仙台",
        "札幌": "札幌", "那霸": "那霸", "金泽": "金澤", "奈良": "奈良",
        // 韩国城市
        "首尔": "首爾", "釜山": "釜山", "济州岛": "濟州島", "大邱": "大邱", "仁川": "仁川",
        "光州": "光州", "大田": "大田", "蔚山": "蔚山",
        // 台湾城市
        "台北": "台北", "台中": "台中", "高雄": "高雄", "台南": "台南", "新北": "新北",
        "桃园": "桃園", "新竹": "新竹", "基隆": "基隆",
        // 泰国城市
        "曼谷": "曼谷", "清迈": "清邁", "普吉岛": "普吉島", "芭达雅": "芭達雅", "华欣": "華欣",
        "苏梅岛": "蘇梅島", "甲米": "甲米", "清莱": "清萊",
        // 马来西亚城市
        "吉隆坡": "吉隆坡", "槟城": "檳城", "兰卡威": "蘭卡威", "沙巴": "沙巴", "马六甲": "馬六甲",
        "怡保": "怡保", "新山": "新山", "古晋": "古晉",
        // 越南城市
        "胡志明市": "胡志明市", "河内": "河內", "岘港": "峴港", "会安": "會安", "芽庄": "芽莊",
        "大叻": "大叻", "顺化": "順化", "下龙湾": "下龍灣",
        // 印尼城市
        "雅加达": "雅加達", "巴厘岛": "峇里島", "日惹": "日惹", "万隆": "萬隆", "泗水": "泗水",
        "棉兰": "棉蘭", "三宝垄": "三寶壟", "龙目岛": "龍目島",
        // 菲律宾城市
        "马尼拉": "馬尼拉", "宿雾": "宿霧", "长滩岛": "長灘島", "巴拉望": "巴拉望", "薄荷岛": "薄荷島",
        "达沃": "達沃", "碧瑶": "碧瑤", "克拉克": "克拉克",
        // 希腊城市
        "雅典": "雅典", "圣托里尼": "聖托里尼", "米克诺斯": "米克諾斯", "克里特岛": "克里特島",
        "罗德岛": "羅德島", "科孚岛": "科孚島", "扎金索斯": "扎金索斯",
        // 德国城市
        "柏林": "柏林", "慕尼黑": "慕尼黑", "汉堡": "漢堡", "法兰克福": "法蘭克福", "科隆": "科隆",
        "斯图加特": "斯圖加特", "杜塞尔多夫": "杜塞爾多夫", "多特蒙德": "多特蒙德",
        // 英国城市
        "伦敦": "倫敦", "爱丁堡": "愛丁堡", "曼彻斯特": "曼徹斯特", "伯明翰": "伯明翰", "利物浦": "利物浦",
        "格拉斯哥": "格拉斯哥", "利兹": "利茲", "谢菲尔德": "謝菲爾德",
        // 意大利城市
        "罗马": "羅馬", "米兰": "米蘭", "威尼斯": "威尼斯", "佛罗伦萨": "佛羅倫薩", "那不勒斯": "那不勒斯",
        "都灵": "都靈", "博洛尼亚": "博洛尼亞", "热那亚": "熱那亞",
        // 西班牙城市
        "马德里": "馬德里", "巴塞罗那": "巴塞羅那", "瓦伦西亚": "瓦倫西亞", "塞维利亚": "塞維利亞",
        "格拉纳达": "格拉納達", "毕尔巴鄂": "畢爾巴鄂", "马拉加": "馬拉加",
        // 法国城市
        "巴黎": "巴黎", "里昂": "里昂", "马赛": "馬賽", "图卢兹": "圖盧茲", "尼斯": "尼斯",
        "南特": "南特", "斯特拉斯堡": "斯特拉斯堡", "蒙彼利埃": "蒙彼利埃",
        // 奥地利城市
        "维也纳": "維也納", "萨尔茨堡": "薩爾茨堡", "因斯布鲁克": "因斯布魯克", "格拉茨": "格拉茨",
        "林茨": "林茨", "克拉根福": "克拉根福",
        // 美国城市
        "纽约": "紐約", "洛杉矶": "洛杉磯", "芝加哥": "芝加哥", "休斯顿": "休斯頓", "凤凰城": "鳳凰城",
        "费城": "費城", "圣安东尼奥": "聖安東尼奧", "圣地亚哥": "聖地亞哥", "达拉斯": "達拉斯",
        "旧金山": "舊金山", "西雅图": "西雅圖", "波士顿": "波士頓", "华盛顿": "華盛頓", "迈阿密": "邁阿密",
        "拉斯维加斯": "拉斯維加斯", "奥兰多": "奧蘭多",
        // 墨西哥城市
        "墨西哥城": "墨西哥城", "坎昆": "坎昆", "瓜达拉哈拉": "瓜達拉哈拉", "蒙特雷": "蒙特雷",
        // 土耳其城市
        "伊斯坦布尔": "伊斯坦布爾", "安卡拉": "安卡拉", "伊兹密尔": "伊茲密爾", "安塔利亚": "安塔利亞",
        "卡帕多奇亚": "卡帕多奇亞", "博德鲁姆": "博德魯姆", "库萨达斯": "庫薩達斯"
    ]
    
    // 城市英语名称映射
    static let cityEnglishNames: [String: String] = [
        // 中国城市
        "北京": "Beijing", "上海": "Shanghai", "廣州": "Guangzhou", "深圳": "Shenzhen", "成都": "Chengdu",
        "杭州": "Hangzhou", "西安": "Xi'an", "重慶": "Chongqing", "蘇州": "Suzhou", "武漢": "Wuhan",
        "南京": "Nanjing", "天津": "Tianjin", "鄭州": "Zhengzhou", "長沙": "Changsha",
        "三亞": "Sanya", "麗江": "Lijiang", "大理": "Dali", "桂林": "Guilin", "張家界": "Zhangjiajie",
        "九寨溝": "Jiuzhaigou", "黃山": "Huangshan", "廬山": "Lushan", "峨眉山": "Mount Emei",
        "泰山": "Mount Tai", "華山": "Mount Hua",
        // 日本城市
        "東京": "Tokyo", "京都": "Kyoto", "大阪": "Osaka", "沖繩": "Okinawa", "福岡": "Fukuoka",
        "名古屋": "Nagoya", "橫濱": "Yokohama", "神戶": "Kobe", "廣島": "Hiroshima",
        // 韩国城市
        "首爾": "Seoul", "釜山": "Busan", "濟州島": "Jeju Island", "大邱": "Daegu", "仁川": "Incheon",
        // 台湾城市
        "台北": "Taipei", "台中": "Taichung", "高雄": "Kaohsiung", "台南": "Tainan",
        // 泰国城市
        "曼谷": "Bangkok", "清邁": "Chiang Mai", "普吉島": "Phuket", "芭達雅": "Pattaya",
        // 马来西亚城市
        "吉隆坡": "Kuala Lumpur", "檳城": "Penang", "蘭卡威": "Langkawi", "沙巴": "Sabah",
        // 越南城市
        "胡志明市": "Ho Chi Minh City", "河內": "Hanoi", "峴港": "Da Nang", "會安": "Hoi An",
        // 印尼城市
        "雅加達": "Jakarta", "峇里島": "Bali", "日惹": "Yogyakarta", "萬隆": "Bandung",
        // 菲律宾城市
        "馬尼拉": "Manila", "宿霧": "Cebu", "長灘島": "Boracay", "巴拉望": "Palawan",
        // 希腊城市
        "雅典": "Athens", "聖托里尼": "Santorini", "米克諾斯": "Mykonos", "克里特島": "Crete",
        // 德国城市
        "柏林": "Berlin", "慕尼黑": "Munich", "漢堡": "Hamburg", "法蘭克福": "Frankfurt", "科隆": "Cologne",
        // 英国城市
        "倫敦": "London", "愛丁堡": "Edinburgh", "曼徹斯特": "Manchester", "伯明翰": "Birmingham",
        // 意大利城市
        "羅馬": "Rome", "米蘭": "Milan", "威尼斯": "Venice", "佛羅倫薩": "Florence", "那不勒斯": "Naples",
        // 西班牙城市
        "馬德里": "Madrid", "巴塞羅那": "Barcelona", "瓦倫西亞": "Valencia", "塞維利亞": "Seville",
        // 法国城市
        "巴黎": "Paris", "里昂": "Lyon", "馬賽": "Marseille", "圖盧茲": "Toulouse", "尼斯": "Nice",
        // 奥地利城市
        "維也納": "Vienna", "薩爾茨堡": "Salzburg", "因斯布魯克": "Innsbruck", "格拉茨": "Graz",
        // 美国城市
        "紐約": "New York", "洛杉磯": "Los Angeles", "芝加哥": "Chicago", "休斯頓": "Houston",
        "舊金山": "San Francisco", "西雅圖": "Seattle", "波士頓": "Boston", "華盛頓": "Washington",
        "邁阿密": "Miami", "拉斯維加斯": "Las Vegas", "奧蘭多": "Orlando",
        // 墨西哥城市
        "墨西哥城": "Mexico City", "坎昆": "Cancun", "瓜達拉哈拉": "Guadalajara",
        // 土耳其城市
        "伊斯坦布爾": "Istanbul", "安卡拉": "Ankara", "伊茲密爾": "Izmir", "安塔利亞": "Antalya",
        "卡帕多奇亞": "Cappadocia", "博德魯姆": "Bodrum"
    ]
    
    /// 转换为繁体（如果存在映射）
    static func toTraditional(_ text: String) -> String {
        // 先检查国家映射
        if let traditional = countrySimplifiedToTraditional[text] {
            return traditional
        }
        // 再检查城市映射
        if let traditional = citySimplifiedToTraditional[text] {
            return traditional
        }
        return text
    }
    
    /// 转换为简体（反向查找）
    static func toSimplified(_ text: String) -> String {
        // 检查国家映射
        for (simplified, traditional) in countrySimplifiedToTraditional {
            if traditional == text {
                return simplified
            }
        }
        // 检查城市映射
        for (simplified, traditional) in citySimplifiedToTraditional {
            if traditional == text {
                return simplified
            }
        }
        return text
    }
    
    /// 获取英语名称（如果存在）
    static func toEnglish(_ text: String) -> String {
        // 先检查国家映射
        if let english = countryEnglishNames[text] {
            return english
        }
        // 再检查城市映射
        if let english = cityEnglishNames[text] {
            return english
        }
        return text
    }
    
    /// 获取所有可能的名称变体（简体、繁体、英语）
    static func getAllVariants(_ text: String) -> [String] {
        var variants: Set<String> = [text]
        
        // 添加繁体
        let traditional = toTraditional(text)
        if traditional != text {
            variants.insert(traditional)
        }
        
        // 添加简体
        let simplified = toSimplified(text)
        if simplified != text {
            variants.insert(simplified)
        }
        
        // 添加英语
        let english = toEnglish(text)
        if english != text {
            variants.insert(english)
        }
        
        // 如果当前是繁体，也查找对应的简体
        if text == traditional {
            variants.insert(simplified)
        }
        
        return Array(variants)
    }
    
    /// 检查文本是否匹配（支持简体、繁体、英语）
    static func matches(_ text: String, searchTerm: String) -> Bool {
        let lowerSearch = searchTerm.lowercased()
        
        // 获取所有变体
        let variants = getAllVariants(text)
        
        // 检查所有变体是否匹配
        for variant in variants {
            if variant.lowercased().contains(lowerSearch) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - 目的地数据结构

/// 城市信息（未来可扩展为数据库模型）
public struct CityInfo: Identifiable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let country: String
    public var attractions: [String]?  // 周边特色（未来从数据库加载）
    public var tags: [String]?         // 标签（如：历史、自然、购物等）
    public var lastUpdated: Date?     // 最后更新时间
    
    public init(
        id: UUID = UUID(),
        name: String,
        country: String,
        attractions: [String]? = nil,
        tags: [String]? = nil,
        lastUpdated: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.attractions = attractions
        self.tags = tags
        self.lastUpdated = lastUpdated
    }
}

/// 国家信息（未来可扩展为数据库模型）
public struct CountryInfo: Identifiable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let cities: [String]
    public var region: String?        // 地区（如：亚洲、欧洲等）
    public var popularTags: [String]? // 热门标签
    
    public init(
        id: UUID = UUID(),
        name: String,
        cities: [String],
        region: String? = nil,
        popularTags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.cities = cities
        self.region = region
        self.popularTags = popularTags
    }
}

// MARK: - 目的地数据管理器

/// 目的地数据管理器
/// 未来可扩展为从数据库加载，支持周边特色缓存
public class DestinationDataManager {
    public static let shared = DestinationDataManager()
    
    private init() {}
    
    // MARK: - 国家-城市映射数据
    
    /// 获取所有国家-城市映射
    public func getCountriesAndCities() -> [String: [String]] {
        return destinationData
    }
    
    /// 获取所有国家列表（按字母排序）
    public func getAllCountries() -> [String] {
        return Array(destinationData.keys).sorted { country1, country2 in
            // 使用拼音或字母排序
            return country1.localizedCompare(country2) == .orderedAscending
        }
    }
    
    /// 获取指定国家的城市列表（按市、省、地区排序，中国特殊处理）
    public func getCities(for country: String) -> [String] {
        let cities = destinationData[country] ?? []
        
        if country == "中國" {
            // 中国城市按市、省、地区排序
            return sortChineseCities(cities)
        } else {
            // 其他国家保持原有顺序（不按字母排序）
            return cities
        }
    }
    
    /// 中国城市排序：按市、省、地区分类
    /// 注意：大部分中国城市名称没有"市"后缀，但按照行政级别和重要性排序
    private func sortChineseCities(_ cities: [String]) -> [String] {
        // 定义重要城市（一线、新一线城市，通常都是市）
        let importantCities = ["北京", "上海", "廣州", "深圳", "成都", "杭州", "西安", "重慶", "蘇州", "武漢", "南京", "天津", "鄭州", "長沙", "東莞", "佛山", "寧波", "青島", "無錫", "合肥", "昆明", "大連", "廈門", "哈爾濱", "濟南", "福州", "溫州", "石家莊", "泉州", "南寧", "長春", "南昌", "貴陽", "太原"]
        
        var cityList: [String] = []      // 市（重要城市 + 有"市"后缀的）
        var provinceList: [String] = []  // 省（有"省"后缀的）
        var regionList: [String] = []     // 地区/其他（历史文化名城、其他）
        
        for city in cities {
            if importantCities.contains(city) || city.hasSuffix("市") {
                cityList.append(city)
            } else if city.hasSuffix("省") || city.contains("省") {
                provinceList.append(city)
            } else if city.contains("自治区") || city.contains("自治州") || city.contains("地区") {
                regionList.append(city)
            } else {
                // 其他（历史文化名城、一般城市等）
                regionList.append(city)
            }
        }
        
        // 分别排序（保持原有顺序，不按字母排序）
        // 重要城市保持原有顺序，其他按出现顺序
        
        // 合并：市 -> 省 -> 地区
        return cityList + provinceList + regionList
    }
    
    /// 获取指定国家的城市列表（区分城市和旅游景点，中国特殊处理）
    public func getCitiesGrouped(for country: String) -> (cities: [String], attractions: [String]) {
        if country == "中國" {
            let cities = destinationData["中國"] ?? []
            let attractions = destinationData["中國旅遊景點"] ?? []
            return (
                cities: sortChineseCities(cities),  // 使用市、省、地区排序
                attractions: attractions.sorted { $0.localizedCompare($1) == .orderedAscending }
            )
        } else {
            let cities = destinationData[country] ?? []
            return (
                cities: cities,  // 其他国家保持原有顺序
                attractions: []
            )
        }
    }
    
    /// 根据城市名查找国家
    public func getCountry(for city: String) -> String? {
        for (country, cities) in destinationData {
            if cities.contains(city) {
                // 如果是中国旅游景点，返回"中國"
                if country == "中國旅遊景點" {
                    return "中國"
                }
                return country
            }
        }
        return nil
    }
    
    // MARK: - 搜索功能
    
    /// 搜索国家（支持简体、繁体、英语）
    /// - Parameter searchTerm: 搜索关键词
    /// - Returns: 匹配的国家列表（按字母排序）
    public func searchCountries(_ searchTerm: String) -> [String] {
        guard !searchTerm.isEmpty else {
            return getAllCountries()
        }
        
        return getAllCountries().filter { country in
            ChineseConverter.matches(country, searchTerm: searchTerm)
        }
    }
    
    /// 搜索城市（支持简体、繁体、英语）
    /// - Parameters:
    ///   - country: 国家名（可选，如果为 nil 则搜索所有国家）
    ///   - searchTerm: 搜索关键词
    /// - Returns: 匹配的城市列表（中国按市、省、地区排序，其他国家保持原有顺序）
    public func searchCities(in country: String? = nil, searchTerm: String) -> [String] {
        guard !searchTerm.isEmpty else {
            if let country = country {
                return getCities(for: country)
            }
            return []
        }
        
        var results: [String] = []
        
        if let country = country {
            // 搜索指定国家的城市
            let cities = destinationData[country] ?? []
            results.append(contentsOf: cities.filter { city in
                ChineseConverter.matches(city, searchTerm: searchTerm)
            })
            
            // 如果是中国，也搜索旅游景点
            if country == "中國" {
                let attractions = destinationData["中國旅遊景點"] ?? []
                results.append(contentsOf: attractions.filter { attraction in
                    ChineseConverter.matches(attraction, searchTerm: searchTerm)
                })
            }
            
            // 如果是中国，按市、省、地区排序；其他国家保持原有顺序
            if country == "中國" {
                return sortChineseCities(results)
            } else {
                // 其他国家保持原有顺序（不按字母排序）
                return results
            }
        } else {
            // 搜索所有国家的城市
            for (country, cities) in destinationData {
                if country == "中國旅遊景點" {
                    continue // 跳过，已在"中國"中处理
                }
                results.append(contentsOf: cities.filter { city in
                    ChineseConverter.matches(city, searchTerm: searchTerm)
                })
            }
            
            // 去重并保持原有顺序（不按字母排序）
            return Array(Set(results))
        }
    }
    
    /// 全局搜索（搜索所有国家和城市）
    /// - Parameter searchTerm: 搜索关键词
    /// - Returns: (匹配的国家列表, 匹配的城市列表)
    public func globalSearch(_ searchTerm: String) -> (countries: [String], cities: [String]) {
        let countries = searchCountries(searchTerm)
        let cities = searchCities(searchTerm: searchTerm)
        return (countries: countries, cities: cities)
    }
    
    // MARK: - 未来扩展：数据库管理
    
    /// 获取城市的周边特色（未来从数据库加载，避免重复调用 OpenAI）
    /// - Parameters:
    ///   - city: 城市名
    ///   - country: 国家名
    /// - Returns: 周边特色列表，如果数据库中没有则返回 nil
    public func getCachedAttractions(for city: String, country: String) -> [String]? {
        // TODO: 未来实现数据库查询
        // 1. 查询数据库是否有该城市的周边特色缓存
        // 2. 如果有且未过期，直接返回
        // 3. 如果没有或已过期，返回 nil，让调用方使用 OpenAI API
        return nil
    }
    
    /// 保存城市的周边特色到数据库（未来实现）
    /// - Parameters:
    ///   - city: 城市名
    ///   - country: 国家名
    ///   - attractions: 周边特色列表
    public func saveAttractions(for city: String, country: String, attractions: [String]) {
        // TODO: 未来实现数据库保存
        // 1. 将周边特色保存到数据库
        // 2. 记录保存时间，用于判断是否过期
    }
    
    // MARK: - 数据源
    
    /// 国家-城市映射数据
    /// 未来可改为从数据库或配置文件加载
    private let destinationData: [String: [String]] = [
        // 亚洲
        "日本": ["東京", "京都", "大阪", "北海道", "沖繩", "福岡", "名古屋", "橫濱", "神戶", "廣島", "仙台", "札幌", "那霸", "金澤", "奈良"],
        "台灣": ["台北", "台中", "高雄", "台南", "新北", "桃園", "新竹", "基隆", "嘉義", "屏東", "宜蘭", "花蓮", "台東", "澎湖", "金門"],
        "韓國": ["首爾", "釜山", "濟州島", "大邱", "仁川", "光州", "大田", "蔚山", "水原", "高陽", "城南", "富川", "全州", "春川", "江陵"],
        "中國": [
            // 一线城市
            "北京", "上海", "廣州", "深圳",
            // 新一线城市
            "成都", "杭州", "西安", "重慶", "蘇州", "武漢", "南京", "天津", "鄭州", "長沙", "東莞", "佛山", "寧波", "青島", "無錫", "合肥", "昆明", "大連", "廈門", "哈爾濱", "濟南", "福州", "溫州", "石家莊", "泉州", "南寧", "長春", "南昌", "貴陽", "太原", "嘉興", "金華", "珠海", "惠州", "常州", "台州", "煙台", "連雲港", "唐山", "徐州", "汕頭", "洛陽", "海口", "揚州", "臨沂", "鹽城", "湖州", "紹興", "泰州", "濰坊", "鎮江", "邯鄲", "蕪湖", "宜昌", "襄陽", "贛州", "上饒", "衡陽", "孝感", "荊州", "黃岡", "十堰", "恩施", "咸寧", "隨州", "鄂州", "黃石", "荊門", "仙桃", "潛江", "天門",
            // 历史文化名城
            "開封", "安陽", "常熟", "淮安", "南通", "宿遷", "麗水", "衢州", "舟山"
        ],
        "中國旅遊景點": [
            // 旅游城市和景点（单独分类）
            "三亞", "麗江", "大理", "桂林", "張家界", "九寨溝", "黃山", "廬山", "峨眉山", "泰山", "華山", "衡山", "恆山", "嵩山", "武當山", "青城山", "武夷山", "雁蕩山", "普陀山", "五台山", "九華山", "天柱山", "三清山", "龍虎山", "齊雲山", "崆峒山", "雞足山", "梵淨山", "老君山", "雲台山", "天門山", "鳳凰古城", "平遙古城", "宏村", "西遞", "周莊", "同里", "烏鎮", "南潯", "甪直", "木瀆", "錦溪", "千燈", "沙溪", "朱家角", "楓涇", "召稼樓"
        ],
        "泰國": ["曼谷", "清邁", "普吉島", "芭達雅", "華欣", "蘇梅島", "甲米", "清萊", "大城", "素可泰", "拜縣", "清孔", "南邦", "夜豐頌", "湄宏順"],
        "新加坡": ["新加坡"],
        "馬來西亞": ["吉隆坡", "檳城", "蘭卡威", "沙巴", "馬六甲", "怡保", "新山", "古晉", "亞庇", "哥打京那巴魯", "詩巫", "美里", "關丹", "新山", "馬六甲"],
        "越南": ["胡志明市", "河內", "峴港", "會安", "芽莊", "大叻", "順化", "下龍灣", "沙壩", "美奈", "富國島", "芹苴", "海防", "寧平", "廣寧"],
        "印尼": ["雅加達", "峇里島", "日惹", "萬隆", "泗水", "棉蘭", "三寶壟", "龍目島", "巴淡島", "民丹島", "拉布安巴焦", "烏布", "庫塔", "努沙杜瓦", "金巴蘭"],
        "菲律賓": ["馬尼拉", "宿霧", "長灘島", "巴拉望", "薄荷島", "達沃", "碧瑤", "克拉克", "蘇比克", "安吉利斯", "巴科洛德", "伊洛伊洛", "卡加延德奧羅", "三寶顏", "達沃"],
        
        // 欧洲
        "希臘": ["雅典", "聖托里尼", "米克諾斯", "克里特島", "羅德島", "科孚島", "扎金索斯", "帕羅斯", "納克索斯", "米洛斯", "伊奧斯", "福萊甘茲羅斯", "斯基亞索斯", "凱法利尼亞", "萊夫卡達"],
        "德國": ["柏林", "慕尼黑", "漢堡", "法蘭克福", "科隆", "斯圖加特", "杜塞爾多夫", "多特蒙德", "埃森", "萊比錫", "德累斯頓", "紐倫堡", "不來梅", "漢諾威", "杜伊斯堡"],
        "英國": ["倫敦", "愛丁堡", "曼徹斯特", "伯明翰", "利物浦", "格拉斯哥", "利茲", "謝菲爾德", "布里斯托", "卡迪夫", "貝爾法斯特", "紐卡斯爾", "諾丁漢", "萊斯特", "南安普頓"],
        "義大利": ["羅馬", "米蘭", "威尼斯", "佛羅倫薩", "那不勒斯", "都靈", "博洛尼亞", "熱那亞", "巴勒莫", "卡塔尼亞", "巴里", "佛羅倫薩", "比薩", "錫耶納", "維羅納"],
        "西班牙": ["馬德里", "巴塞羅那", "瓦倫西亞", "塞維利亞", "格拉納達", "畢爾巴鄂", "馬拉加", "科爾多瓦", "托萊多", "薩拉曼卡", "聖塞瓦斯蒂安", "聖地亞哥", "薩拉戈薩", "穆爾西亞", "阿利坎特"],
        "法國": ["巴黎", "里昂", "馬賽", "圖盧茲", "尼斯", "南特", "斯特拉斯堡", "蒙彼利埃", "波爾多", "里爾", "雷恩", "蘭斯", "勒阿弗爾", "聖艾蒂安", "格勒諾布爾"],
        "奧地利": ["維也納", "薩爾茨堡", "因斯布魯克", "格拉茨", "林茨", "克拉根福", "維拉赫", "巴德伊舍", "哈爾施塔特", "聖沃爾夫岡", "濱湖采爾", "基茨比厄爾", "多恩比恩", "韋爾斯", "施泰爾"],
        
        // 美洲
        "美國": [
            // 主要城市
            "紐約", "洛杉磯", "芝加哥", "休斯頓", "鳳凰城", "費城", "聖安東尼奧", "聖地亞哥", "達拉斯", "聖何塞", "奧斯汀", "傑克遜維爾", "舊金山", "印第安納波利斯", "哥倫布", "夏洛特", "西雅圖", "丹佛", "華盛頓", "波士頓", "底特律", "納什維爾", "波特蘭", "俄克拉荷馬城", "拉斯維加斯", "巴爾的摩", "路易斯維爾", "密爾沃基", "阿爾伯克基", "圖森", "弗雷斯諾", "薩克拉門托", "長灘", "堪薩斯城", "梅薩", "亞特蘭大", "奧馬哈", "羅利", "邁阿密", "克利夫蘭", "塔爾薩", "奧克蘭", "明尼阿波利斯", "威奇托", "阿靈頓", "科羅拉多斯普林斯", "維吉尼亞海灘", "羅利", "奧馬哈", "邁阿密", "奧克蘭", "明尼阿波利斯", "威奇托", "阿靈頓", "科羅拉多斯普林斯", "維吉尼亞海灘",
            // 旅游城市
            "奧蘭多", "邁阿密", "拉斯維加斯", "舊金山", "波士頓", "華盛頓", "西雅圖", "聖地亞哥", "新奧爾良", "查爾斯頓", "薩凡納", "基韋斯特", "阿斯彭", "維爾", "帕克城", "太浩湖", "優勝美地", "大峽谷", "黃石", "大提頓", "錫安", "布萊斯", "拱門", "峽谷地", "死谷", "約書亞樹", "紅杉", "國王峽谷", "拉森", "火山口湖", "雷尼爾山", "奧林匹克", "北瀑布", "冰川", "落基山", "大沙丘", "梅薩維德", "卡爾斯巴德洞窟", "白沙", "大彎", "瓜達盧佩山", "大本德", "大煙山", "謝南多厄", "藍嶺", "阿卡迪亞", "白山", "格林山", "阿迪朗達克", "五指湖", "千島", "尼亞加拉瀑布", "麥基諾島", "睡熊沙丘", "畫岩", "彩岩", "皇家島", "航海者", "邊界水域", "蘇必利爾湖", "密歇根湖", "休倫湖", "伊利湖", "安大略湖"
        ],
        "墨西哥": ["墨西哥城", "坎昆", "瓜達拉哈拉", "蒙特雷", "普埃布拉", "蒂華納", "萊昂", "華雷斯城", "托雷翁", "克雷塔羅", "梅里達", "聖路易斯波托西", "阿瓜斯卡連特斯", "奇瓦瓦", "埃莫西約"],
        
        // 其他
        "土耳其": ["伊斯坦布爾", "安卡拉", "伊茲密爾", "安塔利亞", "卡帕多奇亞", "博德魯姆", "庫薩達斯", "費特希耶", "馬爾馬里斯", "切什梅", "阿拉尼亞", "錫德", "卡什", "卡萊奇", "奧林波斯"]
    ]
}

//
//  BasicInfoView.swift
//  Secalender
//
//  Created by linping on 2025/1/XX.
//

import SwiftUI
import FirebaseAuth

struct BasicInfoView: View {
    @StateObject private var viewModel = BasicInfoViewModel()
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)? = nil  // 完成回调
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.89, green: 0.95, blue: 0.99), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 標題區域
                        VStack(spacing: 8) {
                            Text("填寫基本資料")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("讓我們更了解你")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
                        // 1. 大頭照
                        VStack(alignment: .leading, spacing: 8) {
                            Text("大頭照")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            HStack {
                                Spacer()
                                
                                if let photoUrl = viewModel.photoUrl, let url = URL(string: photoUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 50))
                                                .foregroundColor(.gray)
                                        )
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 2. 名字
                        VStack(alignment: .leading, spacing: 8) {
                            Text("顯示名稱")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            TextField("請輸入您的名稱", text: $viewModel.displayName)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(.horizontal, 20)
                        
                        // 3. 性別選擇
                        VStack(alignment: .leading, spacing: 8) {
                            Text("性別")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            HStack(spacing: 12) {
                                GenderButton(
                                    title: "男",
                                    isSelected: viewModel.gender == "Male",
                                    action: { viewModel.gender = "Male" }
                                )
                                
                                GenderButton(
                                    title: "女",
                                    isSelected: viewModel.gender == "Female",
                                    action: { viewModel.gender = "Female" }
                                )
                                
                                GenderButton(
                                    title: "不透露",
                                    isSelected: viewModel.gender == "Unknown",
                                    action: { viewModel.gender = "Unknown" }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 4. 地區選擇（全球範圍）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("地區")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            Button {
                                viewModel.showRegionPicker = true
                            } label: {
                                HStack {
                                    Text(viewModel.region.isEmpty ? "請選擇地區" : viewModel.region)
                                        .font(.system(size: 16))
                                        .foregroundColor(viewModel.region.isEmpty ? .gray : .black)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 5. 手機號碼（帶國碼選擇，選填）
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("手機號碼")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                Text("（選填）")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            HStack(spacing: 12) {
                                // 國碼選擇器（選擇時顯示國旗，選擇後只顯示國碼）
                                Button {
                                    viewModel.showCountryCodePicker = true
                                } label: {
                                    HStack(spacing: 4) {
                                        // 只在選擇器中顯示國旗，這裡不顯示
                                        Text(viewModel.selectedCountryCode.code)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.separator), lineWidth: 1)
                                    )
                                }
                                .frame(width: 100)
                                
                                TextField("0912345678", text: $viewModel.phoneNumber)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .keyboardType(.phonePad)
                                
                                if viewModel.phoneVerified {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 24))
                                }
                            }
                            
                            Text("手機號碼驗證將在創建或加入社群時進行")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)
                        
                        // 6. 喜好標籤選擇
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("喜好標籤")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Text("已選擇 \(viewModel.selectedFavoriteTags.count)/6")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            let columns = [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ]
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(UserManager.getAvailableFavoriteTags(), id: \.self) { tag in
                                    TagButton(
                                        tag: tag,
                                        isSelected: viewModel.selectedFavoriteTags.contains(tag),
                                        isDisabled: !viewModel.selectedFavoriteTags.contains(tag) && viewModel.selectedFavoriteTags.count >= 6
                                    ) {
                                        viewModel.toggleFavoriteTag(tag)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                        
                        // 完成按鈕
                        Button {
                            Task {
                                await viewModel.completeBasicInfo()
                                if viewModel.isCompleted {
                                    // 刷新用户状态
                                    FirebaseUserManager.shared.refresh()
                                    // 关闭基本资料页面
                                    isPresented = false
                                    // 调用完成回调
                                    onComplete?()
                                }
                            }
                        } label: {
                            HStack {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text("完成")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                viewModel.canComplete ? Color.blue : Color.gray
                            )
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.canComplete || viewModel.isSaving)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        if let error = viewModel.saveError {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCountryCodePicker) {
                CountryCodePickerView(selectedCountryCode: $viewModel.selectedCountryCode)
            }
            .sheet(isPresented: $viewModel.showRegionPicker) {
                NavigationView {
                    CountryCityPickerView(
                        selectedCountry: $viewModel.selectedCountry,
                        selectedCity: $viewModel.selectedCity,
                        userCountry: nil,
                        onSelect: { country, city in
                            viewModel.selectedCountry = country
                            viewModel.selectedCity = city
                            viewModel.region = "\(country) - \(city)"
                            viewModel.showRegionPicker = false
                        }
                    )
                    .navigationTitle("選擇地區")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}

// MARK: - Gender Button
struct GenderButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? Color.blue : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: 1)
                )
        }
    }
}

// MARK: - Country Code Picker
struct CountryCodePickerView: View {
    @Binding var selectedCountryCode: CountryCode
    @Environment(\.dismiss) private var dismiss
    
    let countryCodes: [CountryCode] = [
        CountryCode(name: "台灣", code: "+886", flag: "🇹🇼"),
        CountryCode(name: "中國", code: "+86", flag: "🇨🇳"),
        CountryCode(name: "香港", code: "+852", flag: "🇭🇰"),
        CountryCode(name: "澳門", code: "+853", flag: "🇲🇴"),
        CountryCode(name: "日本", code: "+81", flag: "🇯🇵"),
        CountryCode(name: "韓國", code: "+82", flag: "🇰🇷"),
        CountryCode(name: "新加坡", code: "+65", flag: "🇸🇬"),
        CountryCode(name: "馬來西亞", code: "+60", flag: "🇲🇾"),
        CountryCode(name: "泰國", code: "+66", flag: "🇹🇭"),
        CountryCode(name: "美國", code: "+1", flag: "🇺🇸"),
        CountryCode(name: "加拿大", code: "+1", flag: "🇨🇦"),
        CountryCode(name: "英國", code: "+44", flag: "🇬🇧"),
        CountryCode(name: "澳洲", code: "+61", flag: "🇦🇺"),
        CountryCode(name: "紐西蘭", code: "+64", flag: "🇳🇿"),
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(countryCodes, id: \.code) { countryCode in
                    Button {
                        selectedCountryCode = countryCode
                        dismiss()
                    } label: {
                        HStack {
                            Text(countryCode.flag)
                                .font(.system(size: 24))
                            Text(countryCode.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(countryCode.code)
                                .foregroundColor(.secondary)
                            if selectedCountryCode.code == countryCode.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("選擇國家/地區")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
    }
}

// MARK: - Country Code Model
struct CountryCode: Identifiable {
    let id = UUID()
    let name: String
    let code: String
    let flag: String
}

// MARK: - View Model
@MainActor
final class BasicInfoViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var phoneNumber: String = ""
    @Published var verificationCode: String = ""
    @Published var verificationCodeSent: Bool = false
    @Published var phoneVerified: Bool = false
    @Published var isSendingCode: Bool = false
    @Published var isVerifying: Bool = false
    @Published var isSaving: Bool = false
    @Published var isCompleted: Bool = false
    @Published var phoneError: String?
    @Published var saveError: String?
    
    // 新增字段
    @Published var photoUrl: String? = nil
    @Published var gender: String = "Unknown"
    @Published var region: String = ""
    @Published var selectedCountry: String? = nil
    @Published var selectedCity: String? = nil
    @Published var selectedFavoriteTags: Set<String> = []
    @Published var selectedCountryCode: CountryCode = CountryCode(name: "台灣", code: "+886", flag: "🇹🇼")
    @Published var showCountryCodePicker: Bool = false
    @Published var showRegionPicker: Bool = false
    
    private var currentUser: User? {
        Auth.auth().currentUser
    }
    
    init() {
        loadUserData()
    }
    
    private func loadUserData() {
        Task {
            guard let userId = currentUser?.uid else { return }
            
            do {
                let user = try await UserManager.shared.getUser(userId: userId)
                
                // 載入現有資料
                if let displayName = user.displayName, !displayName.isEmpty {
                    self.displayName = displayName
                } else if let providerName = user.providerDisplayName, !providerName.isEmpty {
                    self.displayName = providerName
                }
                
                // 載入大頭照
                if let photoUrl = user.photoUrl, !photoUrl.isEmpty {
                    self.photoUrl = photoUrl
                } else if let authUser = Auth.auth().currentUser, let photoUrl = authUser.photoURL?.absoluteString {
                    self.photoUrl = photoUrl
                }
                
                if let phone = user.phone, !phone.isEmpty {
                    self.phoneNumber = phone
                }
                
                self.phoneVerified = user.phoneVerified ?? false
                
                // 載入性別
                if let gender = user.gender, !gender.isEmpty {
                    self.gender = gender
                }
                
                // 載入地區（解析國家和城市）
                if let region = user.region, !region.isEmpty {
                    self.region = region
                    // 嘗試解析 "國家 - 城市" 格式
                    let components = region.components(separatedBy: " - ")
                    if components.count == 2 {
                        self.selectedCountry = components[0]
                        self.selectedCity = components[1]
                    }
                }
                
                // 載入喜好標籤
                if let tags = user.favoriteTags {
                    self.selectedFavoriteTags = Set(tags)
                }
            } catch {
                print("載入用戶資料失敗：\(error)")
            }
        }
    }
    
    var canComplete: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func toggleFavoriteTag(_ tag: String) {
        if selectedFavoriteTags.contains(tag) {
            selectedFavoriteTags.remove(tag)
        } else {
            if selectedFavoriteTags.count < 6 {
                selectedFavoriteTags.insert(tag)
            }
        }
    }
    
    func sendVerificationCode() async {
        guard !phoneNumber.isEmpty else {
            phoneError = "請輸入手機號碼"
            return
        }
        
        isSendingCode = true
        phoneError = nil
        
        do {
            _ = try await PhoneVerificationManager.shared.sendVerificationCode(
                to: phoneNumber,
                countryCode: selectedCountryCode.code
            )
            verificationCodeSent = true
        } catch {
            phoneError = "發送驗證碼失敗：\(error.localizedDescription)"
        }
        
        isSendingCode = false
    }
    
    func verifyCode() async {
        guard !verificationCode.isEmpty else {
            phoneError = "請輸入驗證碼"
            return
        }
        
        isVerifying = true
        phoneError = nil
        
        do {
            try await PhoneVerificationManager.shared.verifyCode(verificationCode)
            phoneVerified = true
            verificationCodeSent = false
            verificationCode = ""
            
            // 更新 Firestore 中的手機號和驗證狀態
            if let userId = currentUser?.uid {
                try? await UserManager.shared.updatePhone(for: userId, to: phoneNumber)
                try? await UserManager.shared.updatePhoneVerified(for: userId, verified: true)
            }
        } catch {
            phoneError = "驗證失敗：\(error.localizedDescription)"
        }
        
        isVerifying = false
    }
    
    func completeBasicInfo() async {
        guard let userId = currentUser?.uid else {
            saveError = "無法獲取用戶資訊"
            return
        }
        
        guard canComplete else {
            saveError = "請完成所有必填項目"
            return
        }
        
        isSaving = true
        saveError = nil
        
        do {
            // 更新顯示名稱
            try await UserManager.shared.updateDisplayName(for: userId, to: displayName.trimmingCharacters(in: .whitespaces))
            
            // 更新性別
            try await UserManager.shared.updateGender(for: userId, to: gender)
            
            // 更新地區（保存為 "國家 - 城市" 格式）
            if !region.isEmpty {
                try await UserManager.shared.updateRegion(for: userId, to: region)
            } else if let country = selectedCountry, let city = selectedCity {
                let regionString = "\(country) - \(city)"
                try await UserManager.shared.updateRegion(for: userId, to: regionString)
            }
            
            // 更新喜好標籤
            try await UserManager.shared.updateFavoriteTags(for: userId, to: Array(selectedFavoriteTags))
            
            // 更新手機號（如果輸入但未驗證，只保存號碼，不標記為已驗證）
            if !phoneNumber.isEmpty {
                try await UserManager.shared.updatePhone(for: userId, to: phoneNumber)
                // 只有在已驗證的情況下才更新驗證狀態
                if phoneVerified {
                    try await UserManager.shared.updatePhoneVerified(for: userId, verified: true)
                }
            }
            
            // 標記基本資料已完成
            try await UserManager.shared.markBasicInfoCompleted(for: userId)
            
            isCompleted = true
        } catch {
            saveError = "儲存失敗：\(error.localizedDescription)"
        }
        
        isSaving = false
    }
}

// MARK: - Preview
#Preview {
    BasicInfoView(isPresented: .constant(true))
}

//
//  BusinessCenterDetailView.swift
//  Secalender
//
//  商業中心完整頁面：總收益、AI 額度、銷售趨勢、創作者權益、設置
//

import SwiftUI

struct BusinessCenterDetailView: View {
    @State private var balanceVisible = true
    @State private var totalBalance: Double = 128450
    @State private var aiUsed: Int = 8240
    @State private var aiTotal: Int = 10000
    @State private var salesTrend: Double = 15.8
    @State private var weeklyData: [Double] = [120, 180, 150, 220, 280, 320, 380]
    @State private var creatorLevel = "business.creator_level_gold".localized()
    @State private var commissionRatio = "85%"
    @State private var recommendationWeight = "1.2x"
    @State private var hasFastSupport = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                totalRevenueCard
                aiQuotaCard
                templateSalesTrendCard
                creatorBenefitsCard
                settingsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.business_title".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 總收益餘額
    private var totalRevenueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("business.total_revenue_title".localized())
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Button(action: { balanceVisible.toggle() }) {
                    Image(systemName: balanceVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            
            Text(balanceVisible ? "NT$ \(formatNumber(Int(totalBalance)))" : "••••••")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                NavigationLink(destination: WithdrawalView()) {
                    HStack(spacing: 8) {
                        Image(systemName: "banknote.fill")
                            .font(.subheadline)
                        Text("business.withdraw".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.25))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: TransactionHistoryView()) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .font(.subheadline)
                        Text("business.income_details".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.25))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    // MARK: - AI 運算額度
    private var aiQuotaCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.blue)
                    Text("business.ai_quota_title".localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                Spacer()
                Button(action: {}) {
                    Text("business.purchase_quota".localized())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            Text("business.ai_quota_remaining".localized())
                .font(.caption)
                .foregroundColor(.secondary)
            
            let remaining = aiTotal - aiUsed
            let progress = Double(remaining) / Double(aiTotal)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(remaining)/\(aiTotal)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * progress, height: 10)
                    }
                }
                .frame(height: 10)
                
                Text("business.ai_quota_estimate".localized(with: 1600))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - 本月模板銷售趨勢
    private var templateSalesTrendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("business.template_sales_trend".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("+\(String(format: "%.1f", salesTrend))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            // 簡化柱狀圖
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(i >= 5 ? Color.blue : Color.blue.opacity(0.4))
                            .frame(height: max(20, CGFloat(weeklyData[i]) / 4))
                        Text(weekdayLabel(i))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private func weekdayLabel(_ i: Int) -> String {
        let labels = ["business.week_mon".localized(), "business.week_tue".localized(), "business.week_wed".localized(),
                      "business.week_thu".localized(), "business.week_fri".localized(), "business.week_sat".localized(),
                      "business.week_today".localized()]
        return i < labels.count ? labels[i] : ""
    }
    
    // MARK: - 創作者權益
    private var creatorBenefitsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("business.creator_benefits".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 6) {
                    Text(creatorLevel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 12) {
                benefitRow(icon: "percent", title: "business.commission_ratio".localized(), value: commissionRatio)
                benefitRow(icon: "chart.line.uptrend.xyaxis", title: "business.recommendation_weight".localized(), value: recommendationWeight)
                benefitRow(icon: "headphones", title: "business.fast_support".localized(), value: nil, hasCheck: hasFastSupport)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private func benefitRow(icon: String, title: String, value: String?, hasCheck: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            if let value = value {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            if hasCheck {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - 設置區域
    private var settingsSection: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: AccountSettingsPlaceholderView()) {
                settingsRow(icon: "gearshape.fill", title: "business.account_settings".localized())
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 44)
            
            NavigationLink(destination: TaxInfoPlaceholderView()) {
                settingsRow(icon: "doc.text.fill", title: "business.tax_info".localized())
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private func settingsRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
    }
    
    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

struct AccountSettingsPlaceholderView: View {
    var body: some View {
        Form {
            Section(header: Text("business.account_settings".localized())) {
                Text("business.account_settings_hint".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("business.account_settings".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TaxInfoPlaceholderView: View {
    var body: some View {
        Form {
            Section(header: Text("business.tax_info".localized())) {
                Text("business.tax_info_hint".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("business.tax_info".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        BusinessCenterDetailView()
    }
}

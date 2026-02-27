//
//  BusinessCenterSection.swift
//  Secalender
//
//  商業中心：代幣、AI額度、模板收益、提現、交易紀錄、推薦碼
//

import SwiftUI

struct BusinessCenterSection: View {
    @State private var revenueBalance: String = "NT$ 2,450"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("member.business_title".localized())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            NavigationLink(destination: BusinessCenterDetailView()) {
                businessRow(icon: "dollarsign.circle.fill", title: "member.revenue_management".localized(), value: revenueBalance)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func businessRow(icon: String, title: String, value: String?) -> some View {
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
            if let value = value {
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
    }
}

// MARK: - TokenBalanceView
struct TokenBalanceView: View {
    @State private var tokenBalance: Int = 1280
    @State private var aiCredits: Int = 50
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("member.business_tokens".localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(tokenBalance) TravelCoins")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(16)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("member.business_ai_credits".localized())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    HStack {
                        Text("\(aiCredits)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("member.business_ai_credits_unit".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.business_tokens".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - TemplateEarningsView
struct TemplateEarningsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                businessCard(title: "member.business_earnings_total".localized(), value: "NT$ 2,450", icon: "banknote.fill")
                businessCard(title: "member.business_earnings_month".localized(), value: "NT$ 380", icon: "calendar")
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.business_earnings".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func businessCard(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - WithdrawalView
struct WithdrawalView: View {
    var body: some View {
        Form {
            Section(header: Text("member.business_withdrawal".localized())) {
                Text("member.business_withdrawal_hint".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("member.business_withdrawal".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - TransactionHistoryView
struct TransactionHistoryView: View {
    var body: some View {
        List {
            Text("member.business_transactions_empty".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("member.business_transactions".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ReferralCodeView
struct ReferralCodeView: View {
    @State private var referralCode = "SECAL2025"
    @State private var copied = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("member.business_referral_hint".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(referralCode)
                    .font(.title)
                    .fontWeight(.bold)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                Button(action: {
                    UIPasteboard.general.string = referralCode
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }) {
                    Label(copied ? "common.copied".localized() : "member.business_referral_copy".localized(), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(copied)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.business_referral".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    BusinessCenterSection()
        .padding()
}

//
//  TravelDateRangeCalendarPicker.swift
//  Secalender
//
//  旅行日期：月曆上點選起日與迄日（多日區間），選完後以文字顯示。
//

import SwiftUI

enum TravelTripDateRangeDisplay {
    static func formattedLine(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        let df = DateFormatter()
        df.locale = Locale.current
        // 僅顯示「月/日」，避免顯示「XXXX年」
        df.setLocalizedDateFormatFromTemplate("MMMd")
        if Calendar.current.isDate(s, inSameDayAs: e) {
            return df.string(from: s)
        }
        return "\(df.string(from: s)) － \(df.string(from: e))"
    }
}

// MARK: - 月曆區間（先點出發日，再點回程日；可「重選」）

struct TravelDateRangeCalendarGrid: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    @State private var visibleMonth: Date = Date()
    /// 已點第一日，待點第二日完成區間
    @State private var pendingFirstDay: Date?
    
    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text(monthYearTitle(visibleMonth))
                    .font(.headline)
                Spacer()
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 4)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols(), id: \.self) { sym in
                    Text(sym)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(monthCells(for: visibleMonth), id: \.id) { cell in
                    if let d = cell.date {
                        dayButton(d)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            visibleMonth = startOfMonth(containing: startDate)
            pendingFirstDay = nil
        }
        .onChange(of: startDate) { _, _ in
            visibleMonth = startOfMonth(containing: startDate)
        }
    }
    
    private func dayButton(_ day: Date) -> some View {
        let d0 = cal.startOfDay(for: day)
        let today = cal.startOfDay(for: Date())
        let isPast = d0 < today
        let s0 = cal.startOfDay(for: startDate)
        let e0 = cal.startOfDay(for: endDate)
        let inRange = (d0 >= s0 && d0 <= e0) || (pendingFirstDay.map { cal.isDate(d0, inSameDayAs: $0) } ?? false)
        let isToday = cal.isDateInToday(d0)
        
        return Button {
            guard !isPast else { return }
            tapDay(d0)
        } label: {
            Text("\(cal.component(.day, from: d0))")
                .font(.body.weight(inRange ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    Circle()
                        .fill(inRange ? Color.blue.opacity(0.22) : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
                )
                .foregroundStyle(isPast ? Color.secondary.opacity(0.35) : (inRange ? Color.blue : Color.primary))
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }
    
    private func tapDay(_ day: Date) {
        if let first = pendingFirstDay {
            if cal.isDate(day, inSameDayAs: first) {
                startDate = day
                endDate = day
                pendingFirstDay = nil
                return
            }
            let a = min(first, day)
            let b = max(first, day)
            startDate = a
            endDate = b
            pendingFirstDay = nil
        } else {
            pendingFirstDay = day
            startDate = day
            endDate = day
        }
    }
    
    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = m
        }
    }
    
    private func startOfMonth(containing date: Date) -> Date {
        let c = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: c) ?? date
    }
    
    private func monthYearTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("yMMM")
        return f.string(from: date)
    }
    
    private func weekdaySymbols() -> [String] {
        let f = DateFormatter()
        f.locale = Locale.current
        return f.shortWeekdaySymbols
    }
    
    private struct MonthCell: Identifiable {
        let id: Int
        let date: Date?
    }
    
    private func monthCells(for monthStart: Date) -> [MonthCell] {
        guard let range = cal.range(of: .day, in: .month, for: monthStart),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: monthStart)) else {
            return []
        }
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [MonthCell] = []
        var id = 0
        for _ in 0..<leading {
            cells.append(MonthCell(id: id, date: nil))
            id += 1
        }
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                cells.append(MonthCell(id: id, date: d))
                id += 1
            }
        }
        while cells.count % 7 != 0 {
            cells.append(MonthCell(id: id, date: nil))
            id += 1
        }
        return cells
    }
}

// MARK: - Sheet

struct TravelDateRangePickerSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var calendarResetId = UUID()
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(TravelTripDateRangeDisplay.formattedLine(start: startDate, end: endDate))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                Text("先點「出發日」，再點「回程日」；同一日點兩下為一日遊")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                TravelDateRangeCalendarGrid(startDate: $startDate, endDate: $endDate)
                    .id(calendarResetId)
                    .padding(.horizontal)
                Spacer(minLength: 0)
            }
            .navigationTitle("旅行日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("重選") {
                        pendingReset()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        clampEndNotBeforeStart()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func pendingReset() {
        let cal = Calendar.current
        let t = cal.startOfDay(for: Date())
        startDate = t
        endDate = t
        calendarResetId = UUID()
    }
    
    private func clampEndNotBeforeStart() {
        let cal = Calendar.current
        let s = cal.startOfDay(for: startDate)
        let e = cal.startOfDay(for: endDate)
        if e < s { endDate = s }
    }
}

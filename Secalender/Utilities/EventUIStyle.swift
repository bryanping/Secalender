//
//  EventUIStyle.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 事件表单UI组件

struct EventCardHeader: View {
    let icon: String
    let title: String
    let iconColor: Color
    
    // 判断是否为系统图标（系统图标通常包含点，如 "clock.fill"）
    private var isSystemIcon: Bool {
        icon.contains(".") && !isEmojiIcon(icon)
    }
    
    // 判断是否为emoji图标（如①②③）
    private func isEmojiIcon(_ text: String) -> Bool {
        // 检查是否包含中文字符或特殊Unicode字符（①②③等）
        return text.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 0x2460 && scalar.value <= 0x24FF) || // 带圈数字
            (scalar.value >= 0x1F300 && scalar.value <= 0x1F9FF) || // Emoji
            (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF) // 中文
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 如果是系统图标，使用 Image(systemName:)
            // 如果是emoji或文字，直接显示 Text
            if isSystemIcon {
            Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            } else {
                Text(icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(12)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray6)))
    }

}

struct GlassTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景色 - 浅灰色
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray6))
                .frame(minHeight: minHeight)
            
            // 文本编辑器
            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.trailing, 20) // 为右下角标识留出空间

            // Placeholder文本
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .allowsHitTesting(false)
            }
            
            // 右下角可延长画框示意标识
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ResizeHandle()
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                }
            }
        }
    }
}

// MARK: - Resize Handle 组件（可延长画框示意标识）
struct ResizeHandle: View {
    var body: some View {
        // 创建三条对角线的resize handle图案 (///)
        Canvas { context, size in
            let spacing: CGFloat = 3.5
            let lineWidth: CGFloat = 1
            let endX: CGFloat = size.width - 2  // 右下角X
            let endY: CGFloat = size.height - 2  // 右下角Y
            
            // 绘制三条对角线，从右下角向左上角延伸，形成 /// 图案
            // 第一条线最短（在右下角），最后一条线最长（延伸到左上角）
            for i in 0..<3 {
                let offset = CGFloat(i) * spacing
                var path = Path()
                // 起点：右下角位置，每条线起点向右上移动
                path.move(to: CGPoint(x: endX - offset, y: endY))
                // 终点：向左上延伸，每条线终点向左上移动
                path.addLine(to: CGPoint(x: endX, y: endY - offset))
                context.stroke(
                    path,
                    with: .color(Color(UIColor.systemGray3)),
                    lineWidth: lineWidth
                )
            }
        }
        .frame(width: 16, height: 16)
    }
}

struct EventFormCard<Content: View>: View {
    let icon: String
    let title: String
    let iconColor: Color
    let content: Content
    
    init(icon: String, title: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                //修改内容：标题移到卡片上方
                EventCardHeader(icon: icon, title: title, iconColor: iconColor)
                
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(16)
                .background( //修改内容：卡片内部白底
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                
            }
            .padding(.horizontal)
        }
}

// MARK: - 日期时间选择器视图（两段式交互）

struct DateTimePickerView: View {
    @Binding var startDate: Date
    @Binding var startTime: Date
    @Binding var endDate: Date?
    @Binding var endTime: Date?
    @Binding var isAllDay: Bool
    
    @Binding var isHasEnd: Bool //修改内容：新增 UI 意图层开关
    
    @State private var showControllerSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showControllerSheet = true
            } label: {
                VStack(spacing: 8) {
                    // 第一行：日期和星期或开始日期时间（蓝色，较大字体，居中）
                    Text(dateText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    // 第二行：时间范围或结束日期时间（灰色，较小字体，居中）
                    Text(timeText)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showControllerSheet) {
            DateTimeControllerSheet(
                title: "日期與時間",
                startDate: $startDate,
                startTime: $startTime,
                endDate: $endDate,
                endTime: $endTime,
                isAllDay: $isAllDay,
                isHasEnd: $isHasEnd //修改内容
            )
            .presentationDetents([.height(320), .medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    // 日期文本（第一行）
    private var dateText: String {
        let locale = Locale(identifier: "zh_TW")
        let calendar = Calendar.current
        
        // 检查是否跨日期
        if !isAllDay, isHasEnd, let ed = endDate {
            let startDay = calendar.startOfDay(for: startDate)
            let endDay = calendar.startOfDay(for: ed)
            
            // 如果跨日期，显示开始日期时间
            if startDay != endDay {
        let mergedStart = merge(date: startDate, time: startTime)
                let df = DateFormatter()
                df.locale = locale
                df.dateFormat = "M月d日 EEE a h:mm"
                return df.string(from: mergedStart)
            }
        }
        
        // 不跨日期时，只显示日期和星期
        let df = DateFormatter()
        df.locale = locale
        df.dateFormat = isAllDay ? "M月d日 EEE" : "M月d日 EEE"
        return df.string(from: startDate)
    }
    
    // 时间文本（第二行）
    private var timeText: String {
        guard !isAllDay else {
            return "整日"
        }
        
        let locale = Locale(identifier: "zh_TW")
        let calendar = Calendar.current
        let mergedStart = merge(date: startDate, time: startTime)
        
        // 如果有结束时间
        if isHasEnd, let et = endTime, let ed = endDate {
            let startDay = calendar.startOfDay(for: startDate)
            let endDay = calendar.startOfDay(for: ed)
            let mergedEnd = merge(date: ed, time: et)
            
            // 如果跨日期，显示结束日期时间
            if startDay != endDay {
                let df = DateFormatter()
                df.locale = locale
                df.dateFormat = "M月d日 EEE a h:mm"
                return df.string(from: mergedEnd)
            } else {
                // 不跨日期时，显示时间范围
            let tf = DateFormatter()
            tf.locale = locale
            tf.dateFormat = "a h:mm"
                let startTimeString = tf.string(from: mergedStart)
                let endTimeString = tf.string(from: mergedEnd)
                return "\(startTimeString) - \(endTimeString)"
        }
        }
        
        // 没有结束时间，只显示开始时间
        let tf = DateFormatter()
        tf.locale = locale
        tf.dateFormat = "a h:mm"
        return tf.string(from: mergedStart)
    }
    
    private func merge(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute, .second], from: time)
        var merged = DateComponents()
        merged.year = d.year
        merged.month = d.month
        merged.day = d.day
        merged.hour = t.hour
        merged.minute = t.minute
        merged.second = t.second
        return cal.date(from: merged) ?? date
    }
}

// MARK: - 只读时间显示组件（用于EventShareView）
struct EventTimeDisplayView: View {
    let event: Event
    
    var body: some View {
        VStack(spacing: 8) {
            // 第一行：日期和星期或开始日期时间（蓝色，较大字体，居中）
            Text(dateText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.blue)
            
            // 第二行：时间范围或结束日期时间（灰色，较小字体，居中）
            Text(timeText)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.08))
        )
    }
    
    // 日期文本（第一行）
    private var dateText: String {
        let locale = Locale(identifier: "zh_TW")
        let calendar = Calendar.current
        
        guard let startDate = event.dateObj,
              let startDateTime = event.startDateTime else {
            return event.date
        }
        
        let isAllDay = event.isAllDay ?? false
        
        // 检查是否跨日期
        if !isAllDay, let endDateObj = event.endDateObj, let endDateTime = event.endDateTime {
            let startDay = calendar.startOfDay(for: startDate)
            let endDay = calendar.startOfDay(for: endDateObj)
            
            // 如果跨日期，显示开始日期时间
            if startDay != endDay {
                let df = DateFormatter()
                df.locale = locale
                df.dateFormat = "M月d日 EEE a h:mm"
                return df.string(from: startDateTime)
            }
        }
        
        // 不跨日期时，只显示日期和星期
        let df = DateFormatter()
        df.locale = locale
        df.dateFormat = isAllDay ? "M月d日 EEE" : "M月d日 EEE"
        return df.string(from: startDate)
    }
    
    // 时间文本（第二行）
    private var timeText: String {
        let locale = Locale(identifier: "zh_TW")
        let calendar = Calendar.current
        let isAllDay = event.isAllDay ?? false
        
        guard !isAllDay else {
            return "整日"
        }
        
        guard let startDate = event.dateObj,
              let startDateTime = event.startDateTime else {
            return event.startTime
        }
        
        // 检查是否有结束时间
        let hasEndTime = event.endTime != nil && event.endTime != event.startTime
        let hasEndDate = event.endDate != nil && event.endDate != event.date
        
        if hasEndTime || hasEndDate {
            if let endDateObj = event.endDateObj, let endDateTime = event.endDateTime {
                let startDay = calendar.startOfDay(for: startDate)
                let endDay = calendar.startOfDay(for: endDateObj)
                
                // 如果跨日期，显示结束日期时间
                if startDay != endDay {
                    let df = DateFormatter()
                    df.locale = locale
                    df.dateFormat = "M月d日 EEE a h:mm"
                    return df.string(from: endDateTime)
                } else {
                    // 不跨日期时，显示时间范围
                    let tf = DateFormatter()
                    tf.locale = locale
                    tf.dateFormat = "a h:mm"
                    let startTimeString = tf.string(from: startDateTime)
                    let endTimeString = tf.string(from: endDateTime)
                    return "\(startTimeString) - \(endTimeString)"
                }
            }
        }
        
        // 没有结束时间，只显示开始时间
        let tf = DateFormatter()
        tf.locale = locale
        tf.dateFormat = "a h:mm"
        return tf.string(from: startDateTime)
    }
}

// MARK: - 日期与时间控制器（Sheet）

struct DateTimeControllerSheet: View {
    let title: String
    
    @Binding var startDate: Date
    @Binding var startTime: Date
    @Binding var endDate: Date?
    @Binding var endTime: Date?
    @Binding var isAllDay: Bool
    
    @Binding var isHasEnd: Bool //修改内容：新增绑定
    
    @Environment(\.dismiss) private var dismiss
    
    // 临时状态（支持取消不保存）
    @State private var tempStartDate: Date
    @State private var tempStartTime: Date
    @State private var tempEndDate: Date?
    @State private var tempEndTime: Date?
    @State private var tempIsAllDay: Bool
    
    @State private var tempIsHasEnd: Bool //修改内容：临时开关（唯一真相）
    
    // 日期/时间 sheet
    @State private var showStartDateSheet = false
    @State private var showStartTimeSheet = false
    @State private var showEndDateSheet = false
    @State private var showEndTimeSheet = false
    
    init(
        title: String,
        startDate: Binding<Date>,
        startTime: Binding<Date>,
        endDate: Binding<Date?>,
        endTime: Binding<Date?>,
        isAllDay: Binding<Bool>,
        isHasEnd: Binding<Bool> //修改内容
    ) {
        self.title = title
        self._startDate = startDate
        self._startTime = startTime
        self._endDate = endDate
        self._endTime = endTime
        self._isAllDay = isAllDay
        self._isHasEnd = isHasEnd //修改内容
        
        _tempStartDate = State(initialValue: startDate.wrappedValue)
        _tempStartTime = State(initialValue: startTime.wrappedValue)
        _tempEndDate = State(initialValue: endDate.wrappedValue)
        _tempEndTime = State(initialValue: endTime.wrappedValue)
        _tempIsAllDay = State(initialValue: isAllDay.wrappedValue)
        
        _tempIsHasEnd = State(initialValue: isHasEnd.wrappedValue) //修改内容
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 整日开关
                VStack(spacing: 0) {
                    HStack {
                        Text("整日")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Toggle("", isOn: $tempIsAllDay)
                            .labelsHidden()
                            .tint(.blue)
                            .onChange(of: tempIsAllDay) { newValue in
                                if newValue {
                                    //修改内容：整日 -> 强制关闭结束时间逻辑（避免状态分叉）
                                    tempIsHasEnd = false
                                    tempEndTime = nil
                                    tempEndDate = nil
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    
                    Divider().opacity(0.25)
                }
                .background(.ultraThinMaterial)
                
                // 内容区
                VStack(spacing: 0) {
                    // 开始
                    HStack {
                        Text("開始")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        
                        HStack(spacing: 12) {
                            CompactPillButton(text: formatDate(tempStartDate, components: .date)) {
                                showStartDateSheet = true
                            }
                            
                            if !tempIsAllDay {
                                CompactPillButton(text: formatDate(tempStartTime, components: .hourAndMinute)) {
                                    showStartTimeSheet = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    Divider().opacity(0.18)
                        .padding(.horizontal, 16)
                    
                    // 结束（只在非整日才显示结束时间逻辑）
                    if !tempIsAllDay {
                        if tempIsHasEnd {
                            // 结束行
                            HStack {
                                Text("結束")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    CompactPillButton(text: formatDate(tempEndDate ?? tempStartDate, components: .date)) {
                                        ensureEndDefaultsIfNeeded() //修改内容：确保有值
                                        showEndDateSheet = true
                                    }
                                    
                                    if let et = tempEndTime {
                                        CompactPillButton(text: formatDate(et, components: .hourAndMinute)) {
                                            ensureEndDefaultsIfNeeded()
                                            showEndTimeSheet = true
                                        }
                                    } else {
                                        // 极端情况保护：hasEnd=true 但 endTime=nil
                                        CompactPillButton(text: formatDate(defaultEndTime(), components: .hourAndMinute)) {
                                            ensureEndDefaultsIfNeeded()
                                            showEndTimeSheet = true
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            
                            // 移除结束时间
                            Button {
                                tempIsHasEnd = false
                                tempEndTime = nil
                                tempEndDate = nil
                            } label: {
                                HStack {
                                    Text("移除結束時間")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // 加入结束时间
                            Button {
                                tempIsHasEnd = true
                                ensureEndDefaultsIfNeeded() //修改内容：只有用户点了才生成默认值
                                showEndTimeSheet = true
                            } label: {
                                HStack {
                                    Text("加入結束時間")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 取消
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                // 保存
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // 修改内容：保存时以 tempIsHasEnd 为准，决定是否清空 endDate/endTime
                        startDate = tempStartDate
                        startTime = tempStartTime
                        isAllDay = tempIsAllDay
                        isHasEnd = tempIsHasEnd
                        
                        if tempIsAllDay {
                            // 整日：不允许结束时间
                            endTime = nil
                            endDate = nil
                            isHasEnd = false
                        } else {
                            if tempIsHasEnd {
                                ensureEndDefaultsIfNeeded()
                                endDate = tempEndDate ?? tempStartDate
                                endTime = tempEndTime ?? defaultEndTime()
                            } else {
                                endDate = nil
                                endTime = nil
                            }
                        }
                        
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .onAppear {
                //修改内容：打开控制器时，彻底尊重 isHasEnd（不再从 endTime 推断）
                if !tempIsHasEnd {
                    tempEndTime = nil
                    tempEndDate = nil
                }
                if tempIsAllDay {
                    tempIsHasEnd = false
                    tempEndTime = nil
                    tempEndDate = nil
                }
            }
        }
        // MARK: - 日期/时间 Sheet
        
        // 开始日期
        .sheet(isPresented: $showStartDateSheet) {
            GraphicalDateSheet(
                title: "日期",
                selection: $tempStartDate,
                onDone: {
                    // 校正：若结束日期早于开始日期，拉回
                    if let ed = tempEndDate, ed < tempStartDate { tempEndDate = tempStartDate }
                    showStartDateSheet = false
                },
                onCancel: {
                    showStartDateSheet = false
                }
            )
        }
        
        // 开始时间
        .sheet(isPresented: $showStartTimeSheet) {
            WheelTimeSheet(
                title: "時間",
                selection: $tempStartTime,
                onDone: {
                    // 若有结束，且结束 <= 开始，则推后
                    if tempIsHasEnd {
                        ensureEndDefaultsIfNeeded()
                        if let et = tempEndTime, et <= tempStartTime {
                            tempEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: tempStartTime) ?? et
                            tempEndDate = tempStartDate
                        }
                    }
                    showStartTimeSheet = false
                },
                onCancel: {
                    showStartTimeSheet = false
                }
            )
        }
        
        // 结束日期（只在 hasEnd 时可弹）
        .sheet(isPresented: $showEndDateSheet) {
            GraphicalDateSheet(
                title: "日期",
                selection: Binding(
                    get: { tempEndDate ?? tempStartDate },
                    set: { newValue in
                        tempEndDate = newValue < tempStartDate ? tempStartDate : newValue
                    }
                ),
                onDone: {
                    showEndDateSheet = false
                },
                onCancel: {
                    showEndDateSheet = false
                }
            )
        }
        
        // 结束时间（只在 hasEnd 时可弹）
        .sheet(isPresented: $showEndTimeSheet) {
            WheelTimeSheet(
                title: "時間",
                selection: Binding(
                    get: { tempEndTime ?? defaultEndTime() },
                    set: { tempEndTime = $0 }
                ),
                onDone: {
                    // 校正结束时间不得早于开始
                    if let et = tempEndTime, et <= tempStartTime {
                        tempEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: tempStartTime) ?? et
                        tempEndDate = tempStartDate
                    }
                    showEndTimeSheet = false
                },
                onCancel: {
                    showEndTimeSheet = false
                }
            )
        }
    }
    
    // MARK: - Helpers
    private func ensureEndDefaultsIfNeeded() { //修改内容：统一补默认值
        guard !tempIsAllDay else { return }
        guard tempIsHasEnd else { return }
        
        if tempEndDate == nil { tempEndDate = tempStartDate }
        if tempEndTime == nil { tempEndTime = defaultEndTime() }
    }
    
    private func defaultEndTime() -> Date { //修改内容
        Calendar.current.date(byAdding: .hour, value: 1, to: tempStartTime) ?? tempStartTime
    }
    
    private func formatDate(_ date: Date, components: DatePickerComponents) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        if components.contains(.date) {
            formatter.dateFormat = "yyyy年M月d日"
        } else if components.contains(.hourAndMinute) {
            formatter.dateFormat = "a h:mm"
        }
        return formatter.string(from: date)
    }
}

// MARK: - 通用按钮样式

private struct CompactPillButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .foregroundColor(.primary)
                .font(.system(size: 16))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 日期/时间 Sheet（解决压缩问题）

private struct GraphicalDateSheet: View {
    let title: String
    @Binding var selection: Date
    let onDone: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                DatePicker("", selection: $selection, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_TW"))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct WheelTimeSheet: View {
    let title: String
    @Binding var selection: Date
    let onDone: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                DatePicker("", selection: $selection, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_TW"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .padding(.top, 10)
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 事件表单卡片组件

/// 标题输入卡片
struct EventTitleCard: View {
    @Binding var title: String
    
    var body: some View {
        EventFormCard(icon: "textformat", title: "标题", iconColor: .blue) {
            GlassTextField(placeholder: "输入标题", text: $title)
        }
        
    }
}

/// 活动介绍卡片
struct EventInformationCard: View {
    @Binding var information: String
    
    var body: some View {
        EventFormCard(icon: "text.alignleft", title: "活動介紹", iconColor: .purple) {
            GlassTextEditor(placeholder: "輸入活動介紹...", text: $information, minHeight: 120)
        }
    }
}

/// 时间信息卡片
struct EventTimeCard: View {
    @Binding var startDate: Date
    @Binding var startTime: Date
    @Binding var endDate: Date?
    @Binding var endTime: Date?
    @Binding var isAllDay: Bool
    @Binding var isHasEnd: Bool
    
    var body: some View {
        EventFormCard(icon: "clock.fill", title: "時間", iconColor: .blue) {
            DateTimePickerView(
                startDate: $startDate,
                startTime: $startTime,
                endDate: $endDate,
                endTime: $endTime,
                isAllDay: $isAllDay,
                isHasEnd: $isHasEnd
            )
        }
    }
}

/// 地点输入卡片
struct EventLocationCard: View {
    @Binding var destination: String
    
    var body: some View {
        EventFormCard(icon: "location.fill", title: "地点", iconColor: .red) {
            GlassTextField(placeholder: "输入地点", text: $destination)
        }
    }
}

/// 设置卡片（包含公开、重复、行事历等）
struct EventSettingsCard: View {
    @Binding var isOpenChecked: Bool
    @Binding var repeatType: String
    @Binding var calendarComponent: String
    
    var body: some View {
        EventFormCard(icon: "gearshape.fill", title: "其他设置", iconColor: .gray) {
            VStack(spacing: 16) {
                Toggle("公开给好友", isOn: $isOpenChecked)
                    .tint(.blue)
                
                HStack {
                    Text("重複")
                        .foregroundColor(.primary)
                    Spacer()
                    Picker("", selection: $repeatType) {
                        Text("永不").tag("never")
                        Text("每天").tag("daily")
                        Text("每週").tag("weekly")
                        Text("每月").tag("monthly")
                        Text("每年").tag("yearly")
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("行事曆")
                        .foregroundColor(.primary)
                    Spacer()
                    Picker("", selection: $calendarComponent) {
                        Text("活動安排").tag("default")
                        Text("工作").tag("work")
                        Text("個人").tag("personal")
                        Text("家庭").tag("family")
                        Text("學習").tag("study")
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

// MARK: - 信息显示组件

/// 信息行组件（用于显示只读信息）
struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 事件操作按钮组件

struct EventActionButton: View {
    let title: String
    let icon: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case destructive
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 12, x: 0, y: 6)
        }
    }
    
    private var gradientColors: [Color] {
        switch style {
        case .primary:
            return [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]
        case .destructive:
            return [Color.red.opacity(0.8), Color.red.opacity(0.6)]
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary:
            return .blue.opacity(0.4)
        case .destructive:
            return .red.opacity(0.4)
        }
    }
}

// MARK: - 事件信息显示组件（从 EventShareView 提取）

/// 标题显示卡片（只读）
struct EventTitleDisplayCard: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// 活动介绍显示卡片（只读）
struct EventInformationDisplayCard: View {
    let information: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.purple)
                Text("活動介紹")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            Text(information)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// 时间信息显示卡片（只读）
struct EventTimeDisplayCard: View {
    let date: String
    let startTime: String
    let endTime: String
    let endDate: String?
    let isAllDay: Bool
    let repeatType: String?
    let calendarComponent: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("时间信息")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            if isAllDay {
                InfoRow(icon: "calendar", iconColor: .blue, title: "日期", value: date)
                if let endDate = endDate, endDate != date {
                    InfoRow(icon: "calendar.badge.clock", iconColor: .blue, title: "結束日期", value: endDate)
                }
                Label("全天事件", systemImage: "sun.max.fill")
                    .foregroundColor(.blue)
                    .font(.subheadline)
            } else {
                InfoRow(icon: "play.circle.fill", iconColor: .green, title: "開始", value: "\(date) \(startTime)")
                if let endDate = endDate, endDate != date {
                    InfoRow(icon: "stop.circle.fill", iconColor: .red, title: "結束", value: "\(endDate) \(endTime)")
                } else {
                    InfoRow(icon: "stop.circle.fill", iconColor: .red, title: "結束時間", value: endTime)
                }
            }
            
            // 重複設置
            if let repeatType = repeatType, repeatType != "never" {
                Divider()
                InfoRow(icon: "repeat", iconColor: .orange, title: "重複", value: getRepeatDisplayText(repeatType))
            }
            
            // 日曆組件
            if let calendarComponent = calendarComponent, !calendarComponent.isEmpty {
                Divider()
                InfoRow(icon: "calendar.badge.plus", iconColor: .green, title: "日曆", value: getCalendarDisplayText(calendarComponent))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func getRepeatDisplayText(_ repeatType: String) -> String {
        switch repeatType {
        case "daily": return "每天"
        case "weekly": return "每週"
        case "monthly": return "每月"
        case "yearly": return "每年"
        default: return "永不"
        }
    }
    
    private func getCalendarDisplayText(_ calendarComponent: String) -> String {
        switch calendarComponent {
        case "event": return "活動安排"
        case "work": return "工作"
        case "personal": return "個人"
        case "family": return "家庭"
        case "health": return "健康"
        case "study": return "學習"
        default: return "活動安排"
        }
    }
}

/// 地点信息显示卡片（只读，带地图按钮）
struct EventLocationDisplayCard: View {
    let destination: String
    let onMapTap: (() -> Void)?
    
    init(destination: String, onMapTap: (() -> Void)? = nil) {
        self.destination = destination
        self.onMapTap = onMapTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.red)
                Text("地点信息")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            if let onMapTap = onMapTap {
                Button(action: onMapTap) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(destination)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Text("点击查看地图")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    Text(destination)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// 邀请人员显示卡片（只读）
struct EventInviteesDisplayCard: View {
    let invitees: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                Text("邀請人員")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            Text(invitees.joined(separator: ", "))
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// 分享操作卡片
struct EventShareActionCard: View {
    let onShareTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
                Text("分享")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            Button(action: onShareTap) {
                HStack {
                    Text("分享活动")
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// 权限设置显示卡片（只读）
struct EventPermissionDisplayCard: View {
    let isOpenChecked: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                Text("权限设置")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            HStack {
                Image(systemName: isOpenChecked ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(isOpenChecked ? .green : .gray)
                Text(isOpenChecked ? "公开给好友" : "仅自己可见")
                    .foregroundColor(isOpenChecked ? .green : .gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

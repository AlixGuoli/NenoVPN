//
//  HistoryView.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/9/19.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject private var localeManager = LocaleDao.shared
    @ObservedObject private var historyManager = ConnectionHistoryManager.shared
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if historyManager.connectionHistory.isEmpty {
                            EmptyHistoryView()
                        } else {
                            ForEach(historyManager.connectionHistory) { record in
                                HistoryCard(record: record, isEditing: isEditing) {
                                    historyManager.deleteRecord(id: record.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(LocalizedText("history"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        HStack(spacing: 16) {
                            Button(LocalizedText("clear_all")) {
                                historyManager.clearHistory()
                            }
                            .foregroundColor(.red)
                            
                            Button(LocalizedText("done")) {
                                isEditing = false
                            }
                            .foregroundColor(.accentColor)
                        }
                    } else {
                        Button(LocalizedText("edit")) {
                            isEditing = true
                        }
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .bindLocale()
    }
}


// MARK: - 空历史视图
struct EmptyHistoryView: View {
    @ObservedObject private var localeManager = LocaleDao.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text(LocalizedText("no_history"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text(LocalizedText("history_description"))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - 历史卡片
struct HistoryCard: View {
    let record: ConnectionRecord
    let isEditing: Bool
    let onDelete: () -> Void
    @ObservedObject private var localeManager = LocaleDao.shared
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 状态图标
                Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(record.success ? .green : .red)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.server)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(formatDate(record.startTime))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // 持续时间
                if record.success {
                    Text(formatDuration(record.duration))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                } else {
                    Text(LocalizedText("failed"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
                
                // 删除按钮（仅在编辑模式下显示）
                if isEditing {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red.opacity(0.7))
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 连接时间范围
            HStack {
                Text(LocalizedText("connected_at"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                
                Text(formatTime(record.startTime))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                if let endTime = record.endTime {
                    Text(" - ")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(formatTime(endTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .alert(LocalizedText("delete_record"), isPresented: $showDeleteAlert) {
            Button(LocalizedText("cancel"), role: .cancel) { }
            Button(LocalizedText("delete"), role: .destructive) {
                onDelete()
            }
        } message: {
            Text(LocalizedText("delete_record_message"))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

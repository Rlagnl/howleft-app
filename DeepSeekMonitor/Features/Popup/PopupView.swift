import SwiftUI
import AppKit

/// 点击菜单栏图标后的弹窗内容（由 NSPopover 承载）
/// NSPopover 自带系统标准半透明磨砂玻璃质感，无需自定义背景
struct PopupView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：CNY 余额总和
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedBalance)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(state.isLowBalance ? .red : .primary)
            }

            // 最后更新时间
            Text("最后更新于 \(formattedDate)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 失败账号提示
            if state.failedAccountCount > 0 {
                Text("有 \(state.failedAccountCount) 个账号请求失败")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // 未配置账号引导
            if state.settings.accounts.isEmpty {
                Text("尚未配置任何账号")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // macOS 14+ 要求用 SettingsLink 打开 Settings scene，不能用普通 Button
                SettingsLinkButton("前往设置添加账号")
            }

            Divider()

            // 操作按钮
            HStack(spacing: 8) {
                Button {
                    Task { await state.refreshNow() }
                } label: {
                    if state.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("立即刷新")
                    }
                }
                .disabled(state.isRefreshing || state.settings.accounts.isEmpty)

                Button("充值") {
                    state.openRechargeURL()
                }

                SettingsLinkButton("设置")
            }

            // 退出按钮
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出 DeepSeek Monitor", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
    }

    /// 余额格式化
    private var formattedBalance: String {
        guard let balance = state.totalBalance else { return "¥--" }
        let value = NSDecimalNumber(decimal: balance).doubleValue
        return "¥" + String(format: "%.2f", value)
    }

    /// 日期格式化
    private var formattedDate: String {
        guard let date = state.lastUpdatedAt else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

/// 打开设置面板的按钮，兼容 macOS 13/14+
/// macOS 14+ 必须用 SettingsLink 打开 Settings scene，否则报错
/// macOS 13 没有 SettingsLink，用 sendAction(showPreferencesWindow:) 回退
struct SettingsLinkButton: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Text(title)
            }
        } else {
            Button(title) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
    }
}

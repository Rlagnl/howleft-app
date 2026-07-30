import SwiftUI
import AppKit

/// 设置面板（独立窗口），Form + Section 原生分组
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var showingAddSheet = false
    @State private var newName = ""
    @State private var newApiKey = ""
    @State private var addError: String?

    var body: some View {
        Form {
            // MARK: - 账号管理
            Section {
                ForEach(state.settings.accounts) { account in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(.body)
                            Text(account.apiKeyMasked)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            state.deleteAccount(account)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Button {
                    showingAddSheet = true
                } label: {
                    Label("添加账号", systemImage: "plus")
                }
            } header: {
                Text("账号")
            } footer: {
                Text("每个账号绑定一个 DeepSeek API Key。同一 DeepSeek 账号下多个 Key 共享余额，请勿重复添加。")
            }

            // MARK: - 轮询
            Section("轮询") {
                Stepper(value: Binding(
                    get: { state.settings.pollingIntervalMinutes },
                    set: { newValue in
                        state.settings.pollingIntervalMinutes = newValue
                        state.pollingIntervalDidChange()
                    }
                ), in: 1...60) {
                    Text("每 \(state.settings.pollingIntervalMinutes) 分钟刷新一次")
                }
            }

            // MARK: - 提醒
            Section("提醒") {
                HStack {
                    Text("余额不足阈值")
                    Spacer()
                    TextField("", value: Binding(
                        get: { state.settings.lowBalanceThreshold },
                        set: { newValue in
                            state.settings.lowBalanceThreshold = newValue
                        }
                    ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("元")
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - 通用
            Section("通用") {
                Toggle("开机自动启动", isOn: Binding(
                    get: { state.settings.launchAtLogin },
                    set: { newValue in
                        state.setLaunchAtLogin(newValue)
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 480)
        .sheet(isPresented: $showingAddSheet) {
            addAccountSheet
        }
        .onAppear {
            // 设置窗口首次打开时未获得焦点，导致标题淡灰、Toggle 显示混合态灰色。
            // 根因：菜单栏应用是 background app，NSApp.activate(ignoringOtherApps:) 在 macOS 14+ 不可靠。
            // 解决：用 NSApplication.activate() 无参版本（macOS 14+），并在下一个 runloop 确保窗口
            // 已创建后再 makeKeyAndOrderFront，强制成为 key window。
            activateSettingsWindow()
        }
    }

    /// 添加账号的 sheet
    private var addAccountSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加账号")
                .font(.headline)

            TextField("账号名称（如：工作账号）", text: $newName)
                .textFieldStyle(.roundedBorder)

            SecureField("DeepSeek API Key", text: $newApiKey)
                .textFieldStyle(.roundedBorder)

            if let error = addError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("取消") {
                    resetSheet()
                }
                Button("保存") {
                    saveAccount()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newApiKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func saveAccount() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        let key = newApiKey.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !key.isEmpty else { return }
        do {
            try state.addAccount(name: name, apiKey: key)
            resetSheet()
        } catch {
            addError = "保存失败：\(error.localizedDescription)"
        }
    }

    private func resetSheet() {
        newName = ""
        newApiKey = ""
        addError = nil
        showingAddSheet = false
    }

    /// 激活设置窗口：强制应用获得焦点 + 窗口成为 key window。
    /// 首次打开时用多次重试确保 SwiftUI Window scene 的 NSWindow 已创建完成。
    private func activateSettingsWindow() {
        // 第 1 次：当前 runloop 结束后立即尝试
        activateWindowAttempt()
        // 第 2 次：再延一帧，覆盖 NSWindow 创建延迟较长的场景
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            activateWindowAttempt()
        }
    }

    private func activateWindowAttempt() {
        // macOS 14+ 用无参 activate()，比 ignoringOtherApps 更可靠；macOS 13 回退到旧 API
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        // Settings scene 的窗口标题可能为空或本地化的"设置"，用更通用的方式查找：
        // 找第一个可见的、非 popover 的普通窗口（即设置窗口本身）
        if let window = NSApp.windows.first(where: { $0.isVisible && $0 is NSPanel == false && $0.title.isEmpty == false }) {
            // .floating 层级高于普通应用窗口，避免被其他 app 窗口压住
            window.level = .floating
            // 把窗口置为 key window 并提到最前，触发标题栏和控件的激活态渲染
            window.makeKeyAndOrderFront(nil)
        } else {
            // 回退：直接激活所有可见窗口
            for window in NSApp.windows where window.isVisible {
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

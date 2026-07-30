# DeepSeek 用量监控菜单栏应用 - 实现方案

## Summary

从零搭建一个 macOS 原生菜单栏应用（SwiftUI + `NSStatusItem` + `NSPopover`，部署目标 macOS 13.0），实时监控多个 DeepSeek 账号的 CNY 余额总和，余额不足时推送通知 + 提示音，并提供充值跳转与退出功能。工程以手写 `.xcodeproj` + 源码形式交付，可被 `xcodebuild` 直接编译。

## Current State（实际实现概览）

项目已完成全部功能开发，包含菜单栏常驻、NSPopover 弹窗、设置面板、Keychain 安全存储、余额轮询、通知推送、开机自启、退出功能与自定义 AppIcon。

## Assumptions & Decisions

> 以下决策已在开发过程中与用户确认或根据实际情况调整。

1. **数据模型**：采用**账号分组模型**——每个"账号"绑定 1 个 API Key 用于查询余额，总余额 = 各账号 CNY 余额之和。避免同账号多 Key 重复计数。
2. **工程创建**：手写 `DeepSeekMonitor.xcodeproj/project.pbxproj` + `Info.plist` + `entitlements`，不依赖 Xcode GUI。
3. **设置面板**：macOS `Settings` scene，从弹窗通过 `SettingsLink`（macOS 14+）/ `showPreferencesWindow:`（macOS 13）打开。
4. **App Sandbox**：关闭（`com.apple.security.app-sandbox = false`），因为 ad-hoc 签名下 Keychain 的 `kSecUseDataProtectionKeychain` 会报 `errSecMissingEntitlement`。
5. **不显示 Dock 图标**：`Info.plist` 设 `LSUIElement = true`，`NSApp.setActivationPolicy(.accessory)`，应用仅以菜单栏形态运行。
6. **余额查询**：仅取 `/user/balance` 返回中 `currency == "CNY"` 的 `total_balance`，忽略 USD。
7. **充值 URL**：`https://platform.deepseek.com/usage`。
8. **提示音**：`NSSound(named: "warning")?.play()`，失败回退 `NSSound.beep()`，不依赖通知授权。
9. **轮询实现**：用 `Task` + `try await Task.sleep(for: .seconds(interval))` 循环，API Key 从内存缓存读取，避免每次轮询都触发 Keychain XPC 通信。
10. **Bundle ID**：`com.deepseek.monitor`。
11. **部署目标**：macOS 13.0（`MACOSX_DEPLOYMENT_TARGET = 13.0`）。
12. **Swift 版本**：Swift 5（`SWIFT_VERSION = 5.0`）。
13. **不引入第三方依赖**：纯 Apple SDK。
14. **菜单栏架构**：`AppDelegate` + `NSStatusItem` + `NSPopover`（替代 `MenuBarExtra`），NSPopover 系统自带半透明磨砂玻璃质感。
15. **AppState 单例**：`AppState.shared`，AppDelegate 通过 NotificationCenter 监听状态变化刷新菜单栏标题。

## 文件清单（实际项目结构）

```
deepseek-monitor/
├── DeepSeekMonitor.xcodeproj/
│   └── project.pbxproj
├── DeepSeekMonitor/
│   ├── DeepSeekMonitorApp.swift
│   ├── Info.plist
│   ├── DeepSeekMonitor.entitlements
│   ├── Resources/
│   │   └── AppIcon.icns          # macOS 应用图标（白底 + DeepSeek 蓝鲸鱼 + Monitor 文字）
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/   # Xcode 资产目录中的 AppIcon（1024x1024 源文件）
│   │   └── deepseek-menu-icon.imageset/  # 菜单栏图标（DeepSeek 官方 SVG template image）
│   ├── App/
│   │   └── AppState.swift        # 全局状态管理 + 单例
│   ├── Models/
│   │   └── Account.swift         # 账号模型
│   ├── Core/
│   │   ├── Networking/
│   │   │   ├── DeepSeekClient.swift      # 余额查询客户端
│   │   │   ├── BalanceResponse.swift     # API 响应模型
│   │   │   └── DeepSeekError.swift       # 错误枚举
│   │   ├── Storage/
│   │   │   ├── KeychainStore.swift       # Keychain 封装（无 kSecUseDataProtectionKeychain）
│   │   │   └── AppSettings.swift         # 用户配置持久化
│   │   ├── Polling/
│   │   │   └── BalancePoller.swift       # 轮询调度器
│   │   └── Notifications/
│   │       └── NotificationManager.swift  # 通知 + 提示音 + 阈值去重
│   └── Features/
│       ├── MenuBar/
│       │   └── MenuBarView.swift         # 菜单栏视图（历史遗留，当前未使用）
│       ├── Popup/
│       │   └── PopupView.swift           # 弹窗内容视图
│       └── Settings/
│           └── SettingsView.swift        # 设置面板
├── build-and-install.sh                 # 一键打包安装脚本
└── README.md
```

## 各模块实现细节

### 1. 工程配置文件

#### `DeepSeekMonitor.xcodeproj/project.pbxproj`
- 手写 Xcode 工程文件，包含 1 个 target（`DeepSeekMonitor`）、Sources / Resources / Frameworks build phases
- Resources 包含 `Assets.xcassets` 和 `AppIcon.icns`
- Build settings：`MACOSX_DEPLOYMENT_TARGET = 13.0`、`SWIFT_VERSION = 5.0`、`ENABLE_HARDENED_RUNTIME = YES`

#### `DeepSeekMonitor/Info.plist`
- `LSUIElement = true`（仅菜单栏，无 Dock 图标）
- `CFBundleIconFile = AppIcon`（指向 Resources/AppIcon.icns）
- `LSMinimumSystemVersion = 13.0`
- `NSHighResolutionCapable = true`

#### `DeepSeekMonitor/DeepSeekMonitor.entitlements`
- `com.apple.security.app-sandbox = false`（关闭沙箱）
- `com.apple.security.network.client = true`（网络访问）
- `com.apple.security.files.user-selected.read-write = true`（文件访问，设置面板备用）

### 2. 应用入口

#### `DeepSeekMonitor/DeepSeekMonitorApp.swift`
- `@main` 结构体，承载 `Settings` scene + `AppDelegate`
- `AppDelegate` 用 `NSStatusItem` + `NSPopover` 自实现菜单栏项和弹窗
- 启动时 `NSApp.setActivationPolicy(.accessory)`，无 Dock 图标
- `applicationShouldTerminateAfterLastWindowClosed` 返回 `false`（关闭设置窗口后不退出）
- 菜单栏按钮渲染：正常状态显示 DeepSeek 鲸鱼图标（20pt template image）+ 黑色余额文本；余额不足时显示红色 SF Symbol `exclamationmark.circle.fill` + 红色余额文本
- NSPopover `.behavior = .transient`（点击外部自动关闭），`contentSize = (332, 240)`

### 3. 数据模型

#### `Account.swift`
- `Identifiable, Codable, Equatable`
- `id: UUID` / `name: String` / `apiKeyId: UUID` / `apiKeyMasked: String`
- `mask(apiKey:)` 生成掩码：保留首 4 + 末 4 字符

### 4. 存储层

#### `KeychainStore.swift`
- `enum KeychainStore`（无实例），静态方法 `save/load/delete`
- `kSecClass = kSecClassGenericPassword`，`kSecAttrService = "com.deepseek.monitor"`
- **不使用** `kSecUseDataProtectionKeychain`（ad-hoc 签名下该属性会报错）
- `save` 先 `SecItemDelete` 再 `SecItemAdd`（避免重复添加冲突）
- 错误枚举 `KeychainError`：`unhandledStatus(OSStatus)` + `dataConversionError`

#### `AppSettings.swift`
- `@MainActor final class AppSettings: ObservableObject` + `static let shared`
- 持久化字段：`accounts`（JSON 编码）、`pollingIntervalMinutes`（默认 5）、`lowBalanceThreshold`（默认 10，Decimal 存 String）、`launchAtLogin`、`lastTotalBalance`、`lastUpdatedAt`、`isLowBalance`、`notificationAuthorizationRequested`
- **开机自启初始化**：以 `SMAppService.mainApp.status == .enabled` 为准，而非 UserDefaults 缓存值（避免 Toggle 首次显示为混合态灰色）

### 5. 网络层

#### `DeepSeekError.swift`
- `LocalizedError` 枚举：`unauthorized`、`network(URLError)`、`decoding(Error)`、`unexpectedStatus(Int)`、`noCNYBalance`、`unknown`

#### `BalanceResponse.swift`
- `BalanceResponse: Codable`（`is_available: Bool`、`balance_infos: [BalanceInfo]`）
- `BalanceInfo: Codable`（`currency: String`、`total_balance: String`、`granted_balance: String`、`topped_up_balance: String`）

#### `DeepSeekClient.swift`
- URL: `https://api.deepseek.com/user/balance`
- Header: `Authorization: Bearer {apiKey}`, `Accept: application/json`
- 仅取 `currency == "CNY"` 的 `total_balance`，`Decimal(string:)` 转换

### 6. 状态与轮询

#### `AppState.swift`
- `@MainActor final class AppState: ObservableObject` + `static let shared`
- `@Published` 字段：`totalBalance`、`lastUpdatedAt`、`failedAccountCount`、`isLowBalance`、`isRefreshing`
- 持有 `settings: AppSettings.shared`、`poller: BalancePoller`、`notifier: NotificationManager.shared`
- **内存缓存 API Key**：启动时从 Keychain 一次性加载到 `apiKeys: [UUID: String]`，之后轮询只读内存，避免 Keychain XPC 通信
- **Combine 监听**：`totalBalance` + `isLowBalance` 变化时发送 `NSNotification.Name("AppStateChanged")`，AppDelegate 收到后刷新菜单栏标题
- 账号增删：`addAccount(name:apiKey:)` / `deleteAccount(_:)`，同时更新 Keychain + 内存缓存 + poller
- 开机自启：`setLaunchAtLogin(_:)` 调用 `SMAppService.mainApp.register()/.unregister()`，以系统真实状态同步 UI
- 手动刷新：`refreshNow() async`，并发查询所有账号，聚合 CNY 余额

#### `BalancePoller.swift`
- `@MainActor final class BalancePoller`
- 回调模式：`onPoll: ((PollResult) -> Void)?`
- `Task` 循环 + `Task.sleep` 实现定时轮询，启动后立即执行首次
- `update(accounts:apiKeys:intervalMinutes:)` 重启 poller
- `refreshOnce() async`：`withTaskGroup` 并发查询，聚合成功的 CNY 余额求和

### 7. 通知层

#### `NotificationManager.swift`
- `@MainActor final class NotificationManager` + `static let shared`
- **内存缓存授权状态** `cachedAuthorization`：避免每次都查询 usernoted 守护进程触发 XPC 通信
- `handleBalanceTransition`：仅 `充足 -> 不足` 时推送通知 + 播放提示音
- **提示音不依赖通知授权**：无论授权与否都播放 `NSSound(named: "warning")`

### 8. UI 层 - 菜单栏

#### 菜单栏渲染（`DeepSeekMonitorApp.swift` 中的 `AppDelegate.renderStatusBarTitle`）
- 余额充足：DeepSeek 鲸鱼图标（20pt `NSImage` template）+ 黑色余额文本（`.attributedTitle`）
- 余额不足：SF Symbol `exclamationmark.circle.fill`（红色 `contentTintColor`）+ 红色文本
- 图标通过 `button.imagePosition = .imageLeft` + `button.imageHugsTitle = true` 布局

#### `MenuBarView.swift`（历史遗留，当前未使用）
- 之前 `MenuBarExtra` 时代的 `MenuBarLabel` 视图，现已被 `AppDelegate` 中的 `NSStatusBarButton` 直接渲染替代

### 9. UI 层 - 弹窗

#### `PopupView.swift`
- VStack 布局：大号余额（28pt semibold）+ 最后更新时间 + 失败账号提示 + 未配置引导 + Divider + 操作按钮 + 退出按钮
- 余额不足时余额文本变红
- 未配置账号时显示引导 + "前往设置添加账号"
- 操作按钮：立即刷新、充值、设置（`SettingsLinkButton` 兼容 macOS 13/14+）
- 退出按钮：`NSApplication.shared.terminate(nil)`，电源图标 + 灰色文字
- 弹窗宽 300pt，无自定义背景（NSPopover 自带系统磨砂玻璃质感）

#### `SettingsLinkButton`
- macOS 14+：用 `SettingsLink` 打开 Settings scene
- macOS 13：回退 `NSApp.sendAction(Selector(("showPreferencesWindow:")), ...)`

### 10. UI 层 - 设置面板

#### `SettingsView.swift`
- `Form` + `.formStyle(.grouped)`，4 个 Section：账号管理、轮询、提醒、通用
- 窗口大小：480x480
- `.onAppear`：`NSApp.activate()` + `window.level = .floating` + `makeKeyAndOrderFront(nil)`（确保设置窗口不被其他应用遮挡）
- 添加账号 sheet：名称 + API Key 输入框 + 保存/取消按钮
- 开机自启：`Toggle` 绑定 `state.setLaunchAtLogin(_:)`
- 轮询频率：`Stepper` 1-60 分钟

### 11. 应用图标

#### `AppIcon.icns`
- 白色背景 squircle + DeepSeek 蓝色（`#4D6BFE`）鲸鱼图标 + "Monitor" 文字
- 通过 `sips` + `iconutil` 生成完整的多尺寸 `.icns` 文件（16/32/128/256/512 + @2x）

### 12. 打包脚本

#### `build-and-install.sh`
- 一键 `xcodebuild` 编译 Release 版本 + 复制到 `/Applications`
- 编译产物输出到 `./build/`，安装后自动 `rm -rf ./build` 清理（避免 Spotlight/Launchpad 重复索引）
- 如果 `/Applications` 中已存在旧版本，先删除再覆盖

## Verification Steps

1. **构建验证**：`xcodebuild -scheme DeepSeekMonitor -configuration Debug build` 应成功
2. **运行验证**：
   - 启动后菜单栏出现 DeepSeek 鲸鱼图标 + `¥--`
   - 打开弹窗 → 设置 → 添加账号（名称 + API Key），关闭设置
   - 弹窗显示余额总和 + 最后更新时间
   - 修改阈值高于当前余额，下个轮询周期应收到通知 + 提示音，菜单栏图标变红
   - 点击"充值"打开浏览器跳转 `platform.deepseek.com/usage`
   - 点击"退出 DeepSeek Monitor"正常退出应用
3. **异常路径**：
   - 添加无效 API Key，弹窗显示"有 N 个账号请求失败"，余额基于有效账号
   - 断网后弹窗保留上次余额

## Out of Scope（不实现）

- 7 天历史用量展示（无公开 API）
- USD 余额展示
- 单元测试
- 自动更新 / Sparkle 集成
- 国际化

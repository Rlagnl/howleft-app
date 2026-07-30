# Tasks

- [x] Task 1: 创建 Xcode 工程与菜单栏骨架
  - [x] SubTask 1.1: 创建 macOS App 工程（SwiftUI，部署目标 macOS 13+），配置 Bundle ID、Info.plist（`LSUIElement=true`）、entitlements（网络权限，App Sandbox 关闭）
  - [x] SubTask 1.2: 用 `AppDelegate` + `NSStatusItem` + `NSPopover` 构建常驻菜单栏项和弹窗，显示占位余额文本 `¥--` + DeepSeek 鲸鱼图标
  - [x] SubTask 1.3: 实现应用入口与生命周期（`@main` App + `Settings` scene），设置 `NSApp.setActivationPolicy(.accessory)`，关闭主窗口不退出

- [x] Task 2: 实现 DeepSeek API 客户端（仅余额查询）
  - [x] SubTask 2.1: 实现 `DeepSeekClient`，封装余额查询 `GET https://api.deepseek.com/user/balance`，解析 `balance_infos` 中 `currency == CNY` 的 `total_balance`
  - [x] SubTask 2.2: 实现多账号并发请求与 CNY 余额求和（`withTaskGroup`），单个账号失败不影响整体，统计失败账号数量
  - [x] SubTask 2.3: 实现错误处理与可读错误枚举（无网络、401 鉴权失败、解析失败、无 CNY 条目、非 200 状态码等）

- [x] Task 3: 实现多账号 API Key 安全存储
  - [x] SubTask 3.1: 封装 Keychain 多账号 Key 列表读写（`save/load/delete`），不使用 `kSecUseDataProtectionKeychain`（ad-hoc 签名兼容性），`save` 先删后增避免冲突
  - [x] SubTask 3.2: 轮询时从内存缓存（`[UUID: String]`）读取 API Key，避免每次轮询触发 Keychain XPC 通信
  - [x] SubTask 3.3: 实现未配置任何账号时的引导状态

- [x] Task 4: 实现配置持久化
  - [x] SubTask 4.1: 定义 `AppSettings`（账号列表、轮询频率、阈值、开机自启、缓存余额、通知授权状态），持久化到 UserDefaults
  - [x] SubTask 4.2: 开机自启状态以 `SMAppService.mainApp.status` 系统真实状态为准初始化，避免 Toggle 首次灰色

- [x] Task 5: 实现轮询调度
  - [x] SubTask 5.1: 实现基于 `Task` + `Task.sleep` 的余额轮询调度（非 `Timer`），频率读取自 `AppSettings`（最小 1 分钟，默认 5 分钟），启动后立即首次轮询
  - [x] SubTask 5.2: 余额轮询成功后对所有账号的 CNY 余额求和，通过 `onPoll` 回调刷新 `@Published` 状态，Combine 发通知给 AppDelegate 刷新菜单栏
  - [x] SubTask 5.3: 网络异常或全部账号失败时保留上次成功余额总和并记录"最后更新时间"
  - [x] SubTask 5.4: 配置变更（账号、频率）后自动重启 poller

- [x] Task 6: 实现菜单栏视图与图标状态
  - [x] SubTask 6.1: NSStatusBarButton 显示 `¥12.34` 格式的 CNY 余额总和文本（`.attributedTitle`）
  - [x] SubTask 6.2: 余额充足显示 DeepSeek 鲸鱼图标（20pt template image，`button.image`）；余额不足显示红色 SF Symbol `exclamationmark.circle.fill` + `.contentTintColor = .systemRed`
  - [x] SubTask 6.3: 余额不足时余额文本变红（NSAttributedString `.foregroundColor = .systemRed`）
  - [x] SubTask 6.4: 加载中或失败时显示 `¥--` 占位

- [x] Task 7: 实现弹窗（余额展示 + 操作 + 退出）
  - [x] SubTask 7.1: NSPopover 弹窗顶部展示当前 CNY 余额总和（`¥12.34`，28pt semibold）与"最后更新于 xxx"
  - [x] SubTask 7.2: 提供"立即刷新"按钮（触发一次轮询）、"充值"按钮（`NSWorkspace.open` 打开浏览器）、"设置"入口（`SettingsLinkButton` 兼容 macOS 13/14+）、"退出 DeepSeek Monitor"按钮（`NSApplication.shared.terminate`）
  - [x] SubTask 7.3: 部分账号失败时弹窗底部提示"有 N 个账号请求失败"
  - [x] SubTask 7.4: NSPopover `.behavior = .transient`，系统自带半透明磨砂玻璃质感

- [x] Task 8: 实现设置面板
  - [x] SubTask 8.1: 使用 `Form` + `.formStyle(.grouped)` 原生分组样式
  - [x] SubTask 8.2: 账号列表管理（增删，掩码显示，sheet 输入）、轮询频率（Stepper 1–60 分钟）、余额阈值（TextField）、开机自启（Toggle）
  - [x] SubTask 8.3: 配置变更后立即生效（重启轮询定时器等）
  - [x] SubTask 8.4: `.onAppear` 激活窗口 + 提升层级为 `.floating` + `makeKeyAndOrderFront` 确保不被遮挡

- [x] Task 9: 实现通知、提示音与权限
  - [x] SubTask 9.1: 请求 macOS 通知授权，授权状态缓存到内存（`cachedAuthorization`），避免重复 XPC 查询
  - [x] SubTask 9.2: CNY 余额总和由充足转不足时推送通知并播放系统提示音（`NSSound(named: "warning")`，fallback `NSSound.beep()`），阈值去重
  - [x] SubTask 9.3: 提示音不依赖通知授权，用户拒绝后仍可播放

- [x] Task 10: 实现开机自启动
  - [x] SubTask 10.1: 通过 `SMAppService.mainApp.register()/.unregister()` 注册/注销登录项
  - [x] SubTask 10.2: `AppState.setLaunchAtLogin(_:)` 执行注册后以系统真实状态同步 UI

- [x] Task 11: 应用图标与打包
  - [x] SubTask 11.1: 设计 AppIcon（白色背景 + DeepSeek 蓝 `#4D6BFE` 鲸鱼 + Monitor 文字），通过 `sips` + `iconutil` 生成标准 `.icns`
  - [x] SubTask 11.2: 创建 `build-and-install.sh` 一键编译打包脚本（xcodebuild Release → 复制到 /Applications → 清理编译产物）

- [x] Task 12: 验证与打磨
  - [x] SubTask 12.1: 端到端验证：多账号配置 → CNY 余额总和显示 → 充值跳转 → 阈值通知 + 提示音 → 图标变化 → 退出功能
  - [x] SubTask 12.2: 异常路径验证：无网络、单账号 401、通知拒绝
  - [x] SubTask 12.3: 修复：NSXPCDecoder 警告、Keychain 保存失败、设置窗口层级、Toggle 首次灰色、菜单栏图标间距、弹窗磨砂玻璃
  - [x] SubTask 12.4: 修复：Launchpad 重复显示（脚本编译产物清理）、菜单栏图标颜色与对齐（NSStatusBarButton image + attributedTitle 组合）

# Task Dependencies
- Task 2 依赖 Task 1（需要工程骨架）
- Task 3、Task 4 与 Task 2 并行
- Task 5 依赖 Task 2、Task 4
- Task 6、Task 7 依赖 Task 5
- Task 8 依赖 Task 4、Task 10
- Task 9 依赖 Task 5
- Task 11 依赖 Task 1
- Task 12 依赖 Task 1–Task 11

# 架构说明
- 菜单栏实现：`AppDelegate` + `NSStatusItem` + `NSPopover`（非 `MenuBarExtra`），NSPopover 提供系统原生磨砂玻璃质感
- 状态管理：`AppState.shared` 单例 + Combine 监听 + NotificationCenter 通知 AppDelegate 刷新 UI
- 轮询 API Key：内存缓存 `[UUID: String]`，避免每次轮询触发 Keychain XPC 通信
- 设置窗口：`Settings` scene，macOS 14+ 用 `SettingsLink`，macOS 13 回退 `showPreferencesWindow:`

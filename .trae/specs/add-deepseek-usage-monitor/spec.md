# DeepSeek 用量监控菜单栏应用 Spec

## Why
DeepSeek 用户需要随时掌握账户余额情况，避免在编码或调用过程中因余额耗尽而中断服务。当前 DeepSeek 官方并未提供常驻式桌面监控工具，用户必须主动登录控制台查询，体验割裂。一款常驻 macOS 菜单栏的轻量应用可以让用户一眼看到余额，并在余额不足时主动提醒，从而降低中断风险。

## What Changes
- 新增 macOS 原生应用（SwiftUI + `NSStatusItem` + `NSPopover`，部署目标 macOS 13+），常驻顶部菜单栏，设计风格贴近 macOS 系统原生
- 支持配置**多个** DeepSeek 账号，每个账号绑定一个 API Key，菜单栏与弹窗均展示所有账号的**CNY 余额总和**（不区分具体账号）
- 菜单栏直接显示所有账号的 CNY 充值余额总和（`¥12.34`，2 位小数）与 DeepSeek 官方鲸鱼图标
- 点击菜单栏图标弹出 NSPopover 系统弹窗（自带半透明磨砂玻璃质感），展示：所有账号的 CNY 余额总和、最后更新时间、失败账号数量（如有）
- 弹窗提供"立即刷新"按钮、"充值"按钮（打开默认浏览器跳转 DeepSeek 充值页面）、"设置"入口、"退出 DeepSeek Monitor"按钮
- 余额总和低于阈值（默认 10 元）时通过系统通知中心推送提示**并播放系统提示音**，菜单栏图标同时变红以标识"余额不足"
- 菜单栏图标充足时使用 DeepSeek 官方鲸鱼图标（single-color template image），不足时切换为红色 SF Symbol `exclamationmark.circle.fill`
- API Key 列表安全存储于 Keychain，不得明文落盘
- 支持配置轮询频率（默认 5 分钟）、余额阈值（默认 10 元）、开机自启
- 支持开机自启动
- 应用图标使用白色背景 + DeepSeek 品牌蓝色（`#4D6BFE`）鲸鱼图案 + "Monitor" 文字

> 说明：DeepSeek 官方 `/user/balance` 接口的 `balance_infos` 虽支持 `CNY` 与 `USD` 两种 `currency`，但本应用按用户要求**仅展示 CNY 余额**，对返回中 `currency != CNY` 的条目忽略。DeepSeek 官方未提供按日用量查询 API，故本应用**不展示 7 天用量**，仅聚焦余额监控。采用**账号分组模型**：每个"账号"绑定 1 个 API Key，同一账号多 Key 不重复计算余额。

## Impact
- Affected specs: 无（首个变更）
- Affected code: 全新项目，主要新增以下模块：
  - `AppDelegate`（`DeepSeekMonitorApp.swift`）：应用入口、NSStatusItem 菜单栏项、NSPopover 弹窗管理、生命周期管理
  - `Core/Networking/`：DeepSeek API 客户端（仅余额查询 `/user/balance`），多账号并发请求与 CNY 求和
  - `Core/Storage/`：Keychain 封装（多账号 API Key 列表）、AppSettings（UserDefaults）
  - `Core/Notifications/`：通知调度、去重、提示音
  - `Features/MenuBar/`：菜单栏视图（历史遗留，菜单栏渲染已迁移至 AppDelegate）
  - `Features/Popup/`：弹窗视图（余额、刷新、充值、设置、退出）
  - `Features/Settings/`：设置面板（账号列表管理、轮询频率、阈值、开机自启）
  - `Resources/AppIcon.icns`：应用图标
  - `Assets.xcassets/`：菜单栏图标（DeepSeek SVG）+ AppIcon 资产

## ADDED Requirements

### Requirement: 菜单栏常驻显示 CNY 余额总和
系统 SHALL 在 macOS 顶部菜单栏中常驻显示用户配置的**所有 DeepSeek 账号的 CNY 余额总和**（`¥12.34`，2 位小数），前方显示 DeepSeek 官方鲸鱼图标。余额数据由后台定时轮询每个账号的 `/user/balance` 接口，取 `balance_infos` 中 `currency == CNY` 的 `total_balance` 求和后刷新。

#### Scenario: 正常显示余额
- **WHEN** 应用启动且至少配置一个账号、网络可达
- **THEN** 菜单栏 DeepSeek 鲸鱼图标后跟随显示形如 `¥12.34` 的 CNY 余额总和文本
- **AND** 文本每轮询周期（默认 5 分钟）刷新一次

#### Scenario: 余额加载中或失败
- **WHEN** 首次启动、网络异常或未配置任何账号
- **THEN** 菜单栏显示 `¥--` 占位文本
- **AND** 在弹窗中以可读文案提示具体原因

### Requirement: 弹窗展示余额与操作
系统 SHALL 在用户点击菜单栏图标时弹出 NSPopover 弹窗（系统自带半透明磨砂玻璃质感），展示当前 CNY 余额总和、最后更新时间，并提供刷新、充值、设置、退出四个操作入口。不展示历史用量数据。

#### Scenario: 查看余额
- **WHEN** 用户点击菜单栏图标
- **THEN** 弹窗顶部展示当前所有账号的 CNY 余额总和（`¥12.34`）
- **AND** 展示"最后更新于 xxx"
- **AND** 提供"立即刷新"、"充值"、"设置"按钮，以及"退出 DeepSeek Monitor"退出按钮
- **AND** 弹窗采用 macOS NSPopover 系统原生样式（磨砂玻璃背景、系统字号）

#### Scenario: 充值跳转
- **WHEN** 用户点击"充值"按钮
- **THEN** 使用系统默认浏览器打开 DeepSeek 充值页面（`https://platform.deepseek.com/usage`）
- **AND** 弹窗保持打开，不关闭

#### Scenario: 退出应用
- **WHEN** 用户点击"退出 DeepSeek Monitor"按钮
- **THEN** 调用 `NSApplication.shared.terminate(nil)` 正常退出应用

#### Scenario: 部分账号失败
- **WHEN** 部分账号的余额请求失败
- **THEN** 弹窗余额总和仅基于成功的账号计算
- **AND** 弹窗底部提示"有 N 个账号请求失败"

### Requirement: 余额不足通知与提示音
系统 SHALL 在所有账号的 CNY 余额总和低于用户配置的阈值（默认 10 元）时，通过 macOS 通知中心推送一次性提示**并播放系统提示音**，提示音不依赖通知授权。避免同一低位区间重复打扰。

#### Scenario: 首次跌破阈值
- **WHEN** 轮询结果 CNY 余额总和 < 阈值 且当前状态由"充足"切换为"不足"
- **THEN** 通过通知中心推送一条标题为"DeepSeek 余额不足"的通知，正文包含当前 CNY 余额总和
- **AND** 同时播放系统提示音（`NSSound(named: "warning")`，fallback `NSSound.beep()`）
- **AND** 菜单栏图标与余额文本切换为红色

#### Scenario: 阈值去重
- **WHEN** CNY 余额总和持续低于阈值或继续下降
- **THEN** 不重复推送通知与提示音，除非用户充值后余额总和回升至阈值以上并再次跌破

### Requirement: 多账号 CNY 余额聚合
系统 SHALL 支持用户配置多个 DeepSeek 账号，每个账号绑定一个 API Key，并对所有账号的 CNY 余额进行求和聚合后展示，不区分具体账号的贡献。

#### Scenario: 多账号聚合展示
- **WHEN** 用户配置了多个账号
- **THEN** 菜单栏显示所有账号的 CNY 余额总和
- **AND** 弹窗余额同样为总和
- **AND** 不在界面区分每个账号的单独数值

#### Scenario: 单个账号失败
- **WHEN** 某个账号的余额请求失败（如 401、网络错误）
- **THEN** 该账号不参与本次求和，其他账号正常聚合展示
- **AND** 弹窗中提示"有 N 个账号请求失败"
- **AND** 不影响其他账号的轮询调度

### Requirement: 菜单栏图标状态变化
系统 SHALL 通过菜单栏图标视觉差异标识余额状态。余额充足时使用 DeepSeek 官方鲸鱼图标（20pt single-color template image，自动适配深浅色主题）；余额不足时切换为红色 SF Symbol `exclamationmark.circle.fill`。

#### Scenario: 充足状态
- **WHEN** CNY 余额总和 >= 阈值
- **THEN** 菜单栏显示 DeepSeek 鲸鱼图标 + 黑色余额文本，跟随系统深浅色主题

#### Scenario: 不足状态
- **WHEN** CNY 余额总和 < 阈值
- **THEN** 菜单栏图标切换为红色 `exclamationmark.circle.fill`，余额文本同步变红

### Requirement: API Key 安全存储
系统 SHALL 将用户配置的**多个** DeepSeek API Key 列表存储于 macOS Keychain，不得以明文形式持久化到磁盘或 UserDefaults。轮询时从内存缓存读取 API Key 明文，避免每次轮询都触发 Keychain XPC 通信。

#### Scenario: 增删账号（API Key）
- **WHEN** 用户在设置面板新增、删除某个账号
- **THEN** Keychain 中的 API Key 同步更新，设置面板输入框以掩码显示
- **AND** 应用重启后账号列表仍可从 Keychain 读取
- **AND** 添加账号后立即触发一次余额刷新

#### Scenario: 未配置任何账号
- **WHEN** 应用启动且 Keychain 中不存在任何账号
- **THEN** 菜单栏点击后弹窗引导用户前往设置添加至少一个账号

### Requirement: 轮询刷新
系统 SHALL 按用户配置的频率（默认 5 分钟，最小 1 分钟）轮询**每个**账号的 DeepSeek 余额接口，对 CNY 余额求和后刷新菜单栏与已打开弹窗。

#### Scenario: 轮询刷新余额
- **WHEN** 到达轮询周期
- **THEN** 并发调用每个账号的 `GET /user/balance` 接口获取最新余额
- **AND** 取 `balance_infos` 中 `currency == CNY` 的 `total_balance` 求和，刷新菜单栏与已打开弹窗

#### Scenario: 网络异常
- **WHEN** 余额轮询整体失败（如无网络）
- **THEN** 保留上次成功的 CNY 余额总和与时间戳
- **AND** 在弹窗中提示最后更新时间

### Requirement: 开机自启动
系统 SHALL 提供开机自启动选项，默认关闭，由用户在设置中开启。以 `SMAppService.mainApp.status` 系统真实状态为准。

#### Scenario: 启用自启
- **WHEN** 用户在设置中开启"开机自启动"
- **THEN** 通过 `SMAppService.mainApp.register()` 注册登录项
- **AND** 下次系统登录时应用自动启动

### Requirement: 设置面板
系统 SHALL 提供设置面板，允许用户配置：账号列表（增删）、轮询频率（1–60 分钟）、余额阈值（默认 10 元）、开机自启。

#### Scenario: 修改配置
- **WHEN** 用户修改任一配置并保存
- **THEN** 配置立即生效（如轮询频率变更后下一周期按新频率执行）

#### Scenario: 管理账号列表
- **WHEN** 用户在设置中新增或删除某个账号
- **THEN** Keychain 同步更新，内存缓存同步更新
- **AND** 下个轮询周期按新的账号列表执行

### Requirement: 通知权限
系统 SHALL 在首次需要推送通知前请求 macOS 通知授权；若用户拒绝，提示音仍可播放。授权状态缓存到内存，避免重复 XPC 查询。

#### Scenario: 请求授权
- **WHEN** 首次检测到余额不足且尚未请求过通知授权
- **THEN** 调用系统授权弹窗请求通知权限
- **AND** 授权结果记录到本地并缓存到内存，避免重复请求

#### Scenario: 用户拒绝授权
- **WHEN** 用户拒绝通知授权
- **THEN** 不再推送系统通知（提示音仍可播放）

### Requirement: 视觉风格贴近 macOS 原生
系统 SHALL 在菜单栏、弹窗与设置面板中统一采用 macOS 系统原生视觉语言，确保与系统外观一致。

#### Scenario: 原生外观
- **WHEN** 应用在任何界面运行
- **THEN** 菜单栏充足状态使用 DeepSeek 官方单色鲸鱼图标，自动适配系统深浅色主题
- **AND** 弹窗使用 NSPopover 系统自带半透明磨砂玻璃质感（`.behavior = .transient`）
- **AND** 弹窗尺寸克制（约 300pt 宽），不遮挡工作区
- **AND** 设置面板使用 `Form` + `Section` 原生分组样式（`.formStyle(.grouped)`）
- **AND** 设置窗口首次打开时激活并置为浮动层级（`.floating`），避免被其他应用窗口遮挡
- **AND** 应用图标（AppIcon）为白色背景 + DeepSeek 品牌蓝色图案与文字

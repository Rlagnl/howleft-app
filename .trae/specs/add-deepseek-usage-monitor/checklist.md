# Checklist

## 菜单栏与 CNY 余额展示（多账号总和）
- [x] 菜单栏常驻显示所有账号的 CNY 余额总和，格式为 `¥12.34`（2 位小数）
- [x] 仅取 `/user/balance` 返回中 `currency == CNY` 的 `total_balance`，忽略 USD 等其他币种
- [x] 首次启动 / 网络异常 / 未配置任何账号时显示 `¥--` 占位
- [x] 余额按配置的轮询周期刷新（默认 5 分钟，最小 1 分钟）
- [x] 多账号并发轮询，单账号失败不影响其他账号聚合
- [x] 余额充足时显示 DeepSeek 官方鲸鱼图标（20pt template image，自动适配深浅色）

## 弹窗（余额 + 操作）
- [x] 点击菜单栏图标弹出 NSPopover 弹窗（系统自带半透明磨砂玻璃质感）
- [x] 弹窗顶部展示当前 CNY 余额总和与"最后更新于 xxx"
- [x] 提供"立即刷新"按钮，点击触发一次轮询
- [x] 提供"充值"按钮，点击用系统默认浏览器打开 DeepSeek 充值页面
- [x] 提供"设置"入口（SettingsLinkButton 兼容 macOS 13/14+）
- [x] 提供"退出 DeepSeek Monitor"退出按钮
- [x] 部分账号失败时弹窗底部提示"有 N 个账号请求失败"
- [x] 未配置账号时弹窗引导前往设置
- [x] 弹窗采用 macOS 原生 NSPopover 样式（磨砂玻璃、系统字号、约 300pt 宽）
- [x] 不展示任何历史用量数据（7 天用量已砍掉）

## 余额不足通知与提示音
- [x] CNY 余额总和 < 阈值（默认 10 元）时通过通知中心推送一次性提示
- [x] 同时播放系统提示音（`NSSound(named: "warning")`，fallback `NSSound.beep()`）
- [x] 提示音不依赖通知授权，拒绝授权后仍可播放
- [x] 余额持续低于阈值不重复推送/播放，回升后再次跌破才再次触发
- [x] 通知正文包含当前 CNY 余额总和
- [x] 通知授权状态缓存到内存，避免重复 XPC 查询

## 菜单栏图标状态变化
- [x] 余额充足时使用 DeepSeek 官方鲸鱼图标（single-color template image），自动适配系统深浅色主题
- [x] 余额不足时切换为红色 SF Symbol `exclamationmark.circle.fill` + `contentTintColor = .systemRed`
- [x] 余额不足时余额文本同步变红（NSAttributedString `.foregroundColor = .systemRed`）

## 多账号 API Key 安全存储
- [x] 多个 API Key 存储于 Keychain，未明文落盘
- [x] 设置面板支持增删，输入框掩码显示
- [x] 应用重启后 Key 列表仍可读取
- [x] 未配置任何账号时弹窗引导前往设置
- [x] 轮询时从内存缓存读取 API Key，避免每次触发 Keychain XPC 通信（减少 NSSecureCoding 警告）
- [x] Keychain 不使用 `kSecUseDataProtectionKeychain`（ad-hoc 签名下该属性不兼容）

## 轮询
- [x] 余额按配置频率轮询所有账号，CNY 余额求和后刷新菜单栏与已打开弹窗
- [x] 用 `Task` + `Task.sleep` 循环实现，启动后立即执行首次轮询
- [x] 网络异常时保留上次余额总和并提示"最后更新于 xxx"
- [x] 轮询频率变更后自动重启 poller

## 设置面板
- [x] 使用 `Form` + `.formStyle(.grouped)` 原生分组样式
- [x] 可配置：账号列表（增删）、轮询频率（1–60 分钟，Stepper）、余额阈值（TextField）、开机自启（Toggle）
- [x] 配置变更立即生效（轮询频率、账号列表等）
- [x] 添加账号 sheet：名称输入 + API Key 输入 + 保存/取消
- [x] 设置窗口首次打开时激活 + 置为浮动层级（`.floating`）+ `makeKeyAndOrderFront`（避免被其他窗口遮挡）
- [x] 设置窗口使用 Settings scene（macOS 14+ 用 SettingsLink 打开，macOS 13 回退 showPreferencesWindow:）

## 通知权限
- [x] 首次需要推送通知前请求授权
- [x] 授权结果记录到 AppSettings，缓存到内存避免重复 XPC 查询
- [x] 用户拒绝时提示音仍可播放

## 开机自启动
- [x] 设置中提供"开机自启动"开关，默认关闭
- [x] 通过 `SMAppService.mainApp.register()/.unregister()` 注册/注销登录项
- [x] 以 `SMAppService.mainApp.status` 系统真实状态为准初始化 Toggle（避免首次显示混合态灰色）
- [x] 下次系统登录时自动启动

## 视觉风格与工程
- [x] 部署目标 macOS 13+
- [x] Info.plist 含 `LSUIElement = true`（仅菜单栏，无 Dock 图标）
- [x] `NSApp.setActivationPolicy(.accessory)`
- [x] entitlements 含网络权限（App Sandbox 关闭，因 Keychain 兼容性问题）
- [x] 应用仅以菜单栏形态运行，不显示主窗口
- [x] 整体视觉贴近 macOS 原生（自定义 DeepSeek 图标 + 系统 NSPopover 磨砂玻璃 + Form 原生表单）
- [x] 弹窗尺寸克制（约 300pt 宽），不遮挡工作区
- [x] 自定义 AppIcon（白色背景 + DeepSeek 蓝色鲸鱼 + Monitor 文字，.icns 格式）
- [x] 一键打包脚本 `build-and-install.sh`（编译 Release → 安装到 /Applications → 清理编译产物）

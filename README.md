# HowLeft

macOS 菜单栏应用，实时监控 DeepSeek 账号 CNY 余额。

## 功能

- 菜单栏常驻显示多个 DeepSeek 账号的 CNY 余额总和（`¥12.34`）
- 点击菜单栏图标弹出小弹窗，展示余额总和、最后更新时间、失败账号数
- 余额低于阈值（默认 10 元）时推送系统通知 + 播放提示音
- 菜单栏图标随余额状态变化（充足：HL 图标；不足：红色 `exclamationmark.circle.fill`）
- 弹窗提供"立即刷新""充值""设置"三个操作
- "充值"按钮一键跳转 DeepSeek 控制台
- 支持配置多个账号，每个账号绑定 1 个 API Key
- API Key 安全存储于 Keychain
- 支持配置轮询频率（1–60 分钟）、余额阈值、开机自启

## 安装

### 方式一：下载 DMG 安装（普通用户）

1. 下载 `HowLeft-<版本号>.dmg`，双击挂载
2. 将 **HowLeft** 拖入 **Applications** 文件夹快捷方式
3. 弹出 DMG，从启动台打开 HowLeft

> **⚠️ 关于"无法验证开发者"提示**
>
> 当前发布的 DMG 尚未经过 Apple 签名与公证（签名需要 Apple Developer 账号，后续视用户量补上）。因此**其他用户**首次打开时会被 Gatekeeper 拦截，这是 macOS 对所有未签名应用的默认行为，不是应用本身有问题。放行步骤：
>
> 1. 双击打开应用，在弹出的"无法打开"提示中点**"完成"**（先不要点"移到废纸篓"）
> 2. 打开 **系统设置 → 隐私与安全性**，滚动到页面底部
> 3. 在"已阻止使用"提示旁点击 **"仍要打开"**，并在确认框中再点一次"打开"
>
> 之后启动不再提示。若提示应用"已损坏"，同样是 quarantine 属性导致，可在终端执行：
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/HowLeft.app
> ```
>
> **如何校验下载完整性**：建议从 GitHub Releases 等官方渠道下载，并核对发布页提供的 SHA-256 校验值：
>
> ```bash
> shasum -a 256 HowLeft-<版本号>.dmg
> ```
>
> 校验值一致再放行安装。

### 方式二：从源码构建（推荐，无 Gatekeeper 拦截）

自行编译的产物不携带隔离属性，双击即用，也不存在信任问题：

```bash
git clone <仓库地址>
cd howleft
./build-dmg.sh          # 编译 Release 并打 DMG
# 或只要 app 不要 DMG：
xcodebuild -project HowLeft.xcodeproj -scheme HowLeft -configuration Release build CONFIGURATION_BUILD_DIR=./build
```

依赖：Xcode 15+（含命令行工具）、macOS 13.0+。产物为 universal binary，Intel / Apple Silicon 通用。

## 构建与运行

### 在 Xcode 中启动（开发调试用）

1. 用 Xcode 打开项目：
   ```bash
   open HowLeft.xcodeproj
   ```
2. 在 Xcode 顶部左侧选择 scheme 为 `HowLeft`
3. 按 `Cmd+R`（或点击工具栏的 ▶︎ 运行按钮）编译并启动应用
4. 应用启动后会在菜单栏显示图标，无需打开主窗口

> 开发阶段推荐用此方式，可配合断点调试、查看日志输出。

### 打包脚本（build-dmg.sh）

| 命令 | 用途 |
|---|---|
| `./build-dmg.sh` | 本地自用：ad-hoc 签名 + 打 DMG，输出到 `dist/` |
| `CODESIGN_IDENTITY=... NOTARY_PROFILE=... ./build-dmg.sh` | 正式发布：Developer ID 签名 + 公证 + staple 完整链路 |

正式发布前需一次性存好公证凭证：

```bash
xcrun notarytool store-credentials notary-profile \
    --apple-id "你的AppleID" --team-id "TEAMID" --password "应用专用密码"
```

设置签名身份后，脚本会自动完成：签名 app → 公证 → staple → 打 DMG → 签名 DMG → 公证 DMG → staple DMG。

## 使用

1. 启动后菜单栏会出现 `¥--` 图标
2. 点击图标 → "设置" → 添加账号（输入名称 + DeepSeek API Key）
3. 关闭设置后自动开始轮询，菜单栏显示余额总和
4. 首次余额不足时会请求通知权限

## 设计说明

DeepSeek 同一账号下所有 API Key 共享同一余额。若按 Key 求和会重复计算，故本应用采用**账号分组**模型：每个"账号"绑定 1 个 API Key 用于查询余额，总余额为各账号 CNY 余额之和。

## 技术栈

- SwiftUI + AppKit（`NSStatusItem` / `NSPopover`，macOS 13.0+）
- Keychain（`SecItem` API，`WhenUnlockedThisDeviceOnly`）
- `URLSession` 异步网络（async/await + TaskGroup 并发查询）
- `UNUserNotificationCenter` 通知
- `SMAppService` 开机自启
- Hardened Runtime（App Sandbox 待签名公证后启用）
- 零第三方依赖，universal binary（Intel / Apple Silicon）

## 已知限制

- 不展示历史用量（DeepSeek 官方未提供按日用量查询 API）
- 仅展示 CNY 余额（忽略接口返回的 USD 条目）
- 不支持同一账号下多 Key 自动去重（用户需自行确保每账号只添加一次）

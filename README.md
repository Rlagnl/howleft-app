# DeepSeek Monitor

macOS 菜单栏应用，实时监控 DeepSeek 账号 CNY 余额。

## 功能

- 菜单栏常驻显示多个 DeepSeek 账号的 CNY 余额总和（`¥12.34`）
- 点击菜单栏图标弹出小弹窗，展示余额总和、最后更新时间、失败账号数
- 余额低于阈值（默认 10 元）时推送系统通知 + 播放提示音
- 菜单栏图标随余额状态变化（充足：`dollarsign.circle`；不足：红色 `exclamationmark.circle.fill`）
- 弹窗提供"立即刷新""充值""设置"三个操作
- "充值"按钮一键跳转 DeepSeek 控制台
- 支持配置多个账号，每个账号绑定 1 个 API Key
- API Key 安全存储于 Keychain
- 支持配置轮询频率（1–60 分钟）、余额阈值、开机自启

## 构建与运行

### 方式一：在 Xcode 中启动（开发调试用）

1. 用 Xcode 打开项目：
   ```bash
   open DeepSeekMonitor.xcodeproj
   ```
2. 在 Xcode 顶部左侧选择 scheme 为 `DeepSeekMonitor`
3. 按 `Cmd+R`（或点击工具栏的 ▶︎ 运行按钮）编译并启动应用
4. 应用启动后会在菜单栏显示图标，无需打开主窗口

> 开发阶段推荐用此方式，可配合断点调试、查看日志输出。

### 方式二：用脚本打包并安装到 /Applications（日常使用）

项目根目录提供了 `build-and-install.sh` 脚本，一键编译 Release 版本并复制到 `/Applications`：

```bash
cd ~/MyWorkspace/deepseek-monitor
./build-and-install.sh
```

脚本执行流程：

1. 用 `xcodebuild` 编译 Release 版本到 `./build/`
2. 复制 `DeepSeekMonitor.app` 到 `/Applications/`（如已存在会先删除旧版本）
3. 完成后即可从 Launchpad 或 Spotlight 搜索 "DeepSeekMonitor" 启动

> **⚠️ 首次启动注意事项（应用未签名）**
>
> 本应用仅用于本地自用，未经过 Apple 开发者签名。首次从 `/Applications` 启动时，macOS 的 Gatekeeper 会拦截并提示 "无法打开应用，因为无法验证开发者"。
>
> **放行步骤：**
>
> 1. 打开 **系统设置 → 隐私与安全性**
> 2. 滚动到页面底部，会看到关于 "DeepSeekMonitor" 已被阻止的提示
> 3. 点击 **"仍要打开"** 按钮（若没有该按钮，先点击右下角的 🔒 锁图标解锁）
> 4. 在弹出的确认框中再次点击 "打开"
>
> 完成后系统会记住放行记录，**之后启动不再提示**。也可以在安装前用命令行一次性放行：
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/DeepSeekMonitor.app
> ```
>
> 这会移除应用的隔离属性，跳过 Gatekeeper 检查。

## 使用

1. 启动后菜单栏会出现 `¥--` 图标
2. 点击图标 → "设置" → 添加账号（输入名称 + DeepSeek API Key）
3. 关闭设置后自动开始轮询，菜单栏显示余额总和
4. 首次余额不足时会请求通知权限

## 设计说明

DeepSeek 同一账号下所有 API Key 共享同一余额。若按 Key 求和会重复计算，故本应用采用**账号分组**模型：每个"账号"绑定 1 个 API Key 用于查询余额，总余额为各账号 CNY 余额之和。

## 技术栈

- SwiftUI + `MenuBarExtra`（macOS 13.0+）
- Keychain（`SecItem` API + DataProtectionKeychain）
- `URLSession` 异步网络
- `UNUserNotificationCenter` 通知
- `SMAppService` 开机自启
- App Sandbox + Hardened Runtime

## 已知限制

- 不展示历史用量（DeepSeek 官方未提供按日用量查询 API）
- 仅展示 CNY 余额（忽略接口返回的 USD 条目）
- 不支持同一账号下多 Key 自动去重（用户需自行确保每账号只添加一次）

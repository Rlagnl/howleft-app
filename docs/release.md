# HowLeft 发布指南

本文档说明如何通过 GitHub Actions 发布 DMG 安装包。CI 配置见 [`.github/workflows/release.yml`](../.github/workflows/release.yml)。

## 发布流程总览

```bash
# ① 修改版本号（见下节）
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.1" HowLeft/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 2" HowLeft/Info.plist

# ② 提交并打 tag，推送到 GitHub 触发发布
git add HowLeft/Info.plist
git commit -m "release 1.0.1"
git tag v1.0.1
git push origin main --tags
```

推送 tag 后 Action 自动执行：编译 → 打 DMG → 生成 SHA-256 → 创建 GitHub Release。Release 页面会附带 `HowLeft-1.0.1.dmg` 和 `checksums.txt`。

## 第一步：更新版本号

发布前必须修改 [`HowLeft/Info.plist`](../HowLeft/Info.plist) 中的两个字段：

| 字段 | 含义 | 修改规则 |
|---|---|---|
| `CFBundleShortVersionString` | 用户可见版本号（显示在"关于"、Finder 简介、DMG 文件名） | 每次发布递增，如 `1.0.0` → `1.0.1` |
| `CFBundleVersion` | 构建号（内部计数，区分同版本不同构建） | 每次打包 +1：`1` → `2` → `3` |

**CI 硬校验规则**：tag 名去掉 `v` 前缀后必须与 `CFBundleShortVersionString` **完全一致**，否则 Action 直接报错拒绝发布。此规则防止 DMG 文件名、应用内版本、Release 页三者对不上。`CFBundleVersion` 不参与校验，但作为发布纪律建议一起递增。

也可以直接编辑文件手动改（第 21–24 行附近）：

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.1</string>
<key>CFBundleVersion</key>
<string>2</string>
```

## 第二步：提交、打 tag、推送

三个动作缺一不可，注意顺序：

```bash
git add HowLeft/Info.plist        # 暂存版本号修改（只加这一个文件）
git commit -m "release 1.0.1"     # 先提交
git tag v1.0.1                     # 再在 commit 上打标记
git push origin main --tags        # 推送 commit 和 tag
```

### 注意事项（易踩的坑）

- **普通 `git push` 不会推送 tag**。tag 需要单独推送（`git push origin v1.0.1` 或 `--tags`）。忘了推 tag 会导致 GitHub 上一片安静、Action 不触发。
- **顺序必须"先 commit 后 tag"**。若先打 tag 后改版本号，tag 指向的还是旧 commit，CI 打出的 DMG 版本号是旧的。补救方法：
  ```bash
  git tag -d v1.0.1                # 删除本地错误 tag
  # 修正并 commit 后重新打 tag
  ```
- **tag 名必须 `v` 开头**（如 `v1.0.1`）。这是 workflow 中 `tags: ["v*"]` 的触发规则，`1.0.1` 或 `release-1.0.1` 均不触发。
- **只 add 具体文件**。提交发布时用 `git add HowLeft/Info.plist`，避免 `git add -A` 把无关改动带进发布 commit。

## 触发方式

| 触发方式 | 行为 |
|---|---|
| 推送 `v*` tag | 完整发布：构建 DMG → 生成校验文件 → 创建 GitHub Release |
| 手动触发（workflow_dispatch） | 仅构建：产物存为 workflow artifact，不发布。用于发布前试跑验证 |

**首次使用建议**：先在 GitHub 仓库的 Actions 页面手动触发一次，确认 CI 上 `hdiutil` 打包正常，再发正式 tag。

## 验证发布结果

1. 进入 GitHub 仓库 **Actions** 页面，确认 Release workflow 绿色通过
2. 进入 **Releases** 页面，应看到：
   - `HowLeft-<版本号>.dmg`
   - `checksums.txt`（SHA-256 校验值，供用户按 README 安装章节校验）
3. 本地核对校验值：
   ```bash
   shasum -a 256 HowLeft-<版本号>.dmg
   ```

## 未签名版本的说明

当前发布的 DMG 为 ad-hoc 签名（未经过 Apple Developer 签名与公证），用户首次打开会被 Gatekeeper 拦截，放行步骤见 [README 安装章节](../README.md)。Release 说明中已自动附带此提示。

开通 Apple Developer 账号后，在 Repository Secrets 中配置证书，并在 workflow 中为 `./build-dmg.sh` 注入 `CODESIGN_IDENTITY` 与 `NOTARY_PROFILE` 环境变量，即可启用"签名 + 公证 + staple"完整链路（脚本本身已支持，workflow 需补充证书导入步骤）。

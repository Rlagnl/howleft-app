#!/bin/bash
# 打包 HowLeft 为 DMG 安装包
#
# 本地自用（ad-hoc 签名，仅本机可运行）：
#   ./build-dmg.sh
#
# 正式发布（需 Apple Developer 账号，$99/年）：
#   1. 事先存好公证凭证（只需做一次）：
#      xcrun notarytool store-credentials notary-profile \
#          --apple-id "你的AppleID" --team-id "TEAMID" --password "应用专用密码"
#   2. 运行：
#      CODESIGN_IDENTITY="Developer ID Application: 你的名字 (TEAMID)" \
#      NOTARY_PROFILE="notary-profile" \
#      ./build-dmg.sh
#
# 提供签名身份时自动执行完整发布流程：
#   签名 app -> 公证 app -> staple -> 打 DMG -> 签名 DMG -> 公证 DMG -> staple DMG

set -euo pipefail

PROJECT="HowLeft.xcodeproj"
SCHEME="HowLeft"
APP_NAME="HowLeft.app"
BUILD_DIR="./build"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DIST_DIR="./dist"

# 可选环境变量（为空时走本地自用流程）
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

# ---------- 工具函数 ----------

log() { echo "==> $*"; }

fail() { echo "错误：$*" >&2; exit 1; }

# 用 Developer ID 签名（--options runtime 是公证的硬性要求）
sign() {
    local target="$1"
    log "签名 $target ..."
    codesign --force --deep --options runtime --timestamp \
        --sign "$CODESIGN_IDENTITY" "$target"
}

# 公证并落地凭证（--wait 阻塞等待 Apple 审核结果，通常几分钟）
notarize_and_staple() {
    local target="$1"
    log "公证 $target（等待 Apple 审核，可能需要几分钟）..."
    xcrun notarytool submit "$target" --keychain-profile "$NOTARY_PROFILE" --wait
    log "为 $target 落地公证凭证..."
    xcrun stapler staple "$target"
}

# ---------- 主流程 ----------

cd "$(dirname "$0")"

log "编译 Release 版本..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release build \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" -quiet

APP_PATH="$BUILD_DIR/$APP_NAME"
[ -d "$APP_PATH" ] || fail "编译产物未找到 $APP_PATH"

# 从产物 Info.plist 读取版本号，DMG 文件名带版本
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$APP_PATH/Contents/Info.plist")
DMG_NAME="HowLeft-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# ---- 签名与公证（app 本体）----
if [ -n "$CODESIGN_IDENTITY" ]; then
    sign "$APP_PATH"
    if [ -n "$NOTARY_PROFILE" ]; then
        notarize_and_staple "$APP_PATH"
    fi
else
    # ad-hoc 签名由 xcodebuild 自动完成，验证一下保证产物完整
    codesign --verify "$APP_PATH" || fail "ad-hoc 签名校验失败"
    log "未设置 CODESIGN_IDENTITY，跳过正式签名与公证（产物仅限本机使用）"
fi

# ---- 组装 DMG 内容（app + /Applications 拖拽快捷方式）----
log "组装 DMG 内容..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ---- 生成 DMG（UDZO 压缩格式）----
log "生成 $DMG_NAME ..."
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
hdiutil create -volname "HowLeft" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" -quiet

# ---- DMG 本体的签名与公证 ----
if [ -n "$CODESIGN_IDENTITY" ]; then
    sign "$DMG_PATH"
    if [ -n "$NOTARY_PROFILE" ]; then
        notarize_and_staple "$DMG_PATH"
    fi
fi

# ---- 收尾 ----
rm -rf "$BUILD_DIR"

log "完成！产物：$DMG_PATH"
codesign -dv "$DMG_PATH" 2>&1 | head -2 || true
if [ -z "$CODESIGN_IDENTITY" ]; then
    echo "    提示：当前为未签名版本，仅限本机使用。"
    echo "    公开发布请配置 CODESIGN_IDENTITY 与 NOTARY_PROFILE（见脚本头部说明）。"
fi

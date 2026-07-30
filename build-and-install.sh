#!/bin/bash
# 一键编译 Release 版本并安装到 /Applications
# 用法：在项目根目录运行 ./build-and-install.sh

set -e

PROJECT="DeepSeekMonitor.xcodeproj"
SCHEME="DeepSeekMonitor"
APP_NAME="DeepSeekMonitor.app"

echo "==> 编译 Release 版本..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release build \
    CONFIGURATION_BUILD_DIR="./build" \
    -quiet

APP_PATH="./build/$APP_NAME"

if [ ! -d "$APP_PATH" ]; then
    echo "错误：编译产物未找到 $APP_PATH"
    exit 1
fi

echo "==> 安装到 /Applications..."
# 如果已存在先删除
if [ -d "/Applications/$APP_NAME" ]; then
    rm -rf "/Applications/$APP_NAME"
fi
cp -R "$APP_PATH" "/Applications/"

# 清理编译产物，避免项目目录下的 .app 被 Spotlight/Launchpad 索引导致重复显示
rm -rf "./build"

echo "==> 完成！可以从 Launchpad 或 Spotlight 启动 DeepSeekMonitor"
echo "    路径: /Applications/$APP_NAME"

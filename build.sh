#!/bin/bash
# build.sh — 在 Mac 上编译 AgentLights.app (需要 Xcode Command Line Tools)
# 用法: chmod +x build.sh && ./build.sh
set -e
cd "$(dirname "$0")"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "没找到 swiftc, 先装 Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

APP="AgentLights.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

echo "编译中..."
swiftc -O -o "$APP/Contents/MacOS/AgentLights" main.swift -framework AppKit

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AgentLights</string>
  <key>CFBundleIdentifier</key><string>net.enixjin.agentlights</string>
  <key>CFBundleName</key><string>AgentLights</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

echo "完成: $(pwd)/$APP (双击运行)"

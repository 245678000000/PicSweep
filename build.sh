#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP="图片清理.app"
swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -parse-as-library main.swift -o PicSweep-arm64
swiftc -swift-version 5 -O -target x86_64-apple-macos14.0 -parse-as-library main.swift -o PicSweep-x86_64
lipo -create PicSweep-arm64 PicSweep-x86_64 -output PicSweep && rm PicSweep-arm64 PicSweep-x86_64
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv PicSweep "$APP/Contents/MacOS/"; cp AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>图片清理</string>
<key>CFBundleDisplayName</key><string>图片清理</string>
<key>CFBundleIdentifier</key><string>local.picsweep</string>
<key>CFBundleExecutable</key><string>PicSweep</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSDesktopFolderUsageDescription</key><string>扫描桌面上的图片</string>
<key>NSAppleEventsUsageDescription</key><string>通过访达把 iCloud 中的图片移到废纸篓</string>
<key>NSDownloadsFolderUsageDescription</key><string>扫描下载文件夹中的图片</string>
</dict></plist>
PL
codesign --force --deep -s - "$APP"
echo "Built $APP"

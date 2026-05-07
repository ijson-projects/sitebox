#!/bin/bash

# SiteBox - 打包脚本

echo "🚀 开始打包 SiteBox..."
echo ""

# 检查并准备图标文件
echo "🎨 检查图标文件..."

# 检查 AppIcon.png，如果没有则从样本文件复制
if [ ! -f "custom_icons/AppIcon.png" ]; then
    if [ -f "custom_icons/AppIcon_sample.png" ]; then
        echo "   ℹ️  AppIcon.png 不存在，从 AppIcon_sample.png 复制..."
        cp "custom_icons/AppIcon_sample.png" "custom_icons/AppIcon.png"
        echo "   ✓ 已复制 AppIcon.png"
    else
        echo "   ⚠️  警告: 未找到 AppIcon.png 和 AppIcon_sample.png"
    fi
else
    echo "   ✓ 使用自定义 AppIcon.png"
fi

# 检查 StatusBarIcon.png，如果没有则从样本文件复制
if [ ! -f "custom_icons/StatusBarIcon.png" ]; then
    if [ -f "custom_icons/StatusBarIcon_sample.png" ]; then
        echo "   ℹ️  StatusBarIcon.png 不存在，从 StatusBarIcon_sample.png 复制..."
        cp "custom_icons/StatusBarIcon_sample.png" "custom_icons/StatusBarIcon.png"
        echo "   ✓ 已复制 StatusBarIcon.png"
    else
        echo "   ⚠️  警告: 未找到 StatusBarIcon.png 和 StatusBarIcon_sample.png"
    fi
else
    echo "   ✓ 使用自定义 StatusBarIcon.png"
fi

echo ""

# 检查并替换自定义图标
if [ -f "custom_icons/AppIcon.png" ] || [ -f "custom_icons/StatusBarIcon.png" ]; then
    echo "🎨 检测到自定义图标，正在替换..."

    # 替换应用图标
    if [ -f "custom_icons/AppIcon.png" ]; then
        echo "   ✓ 替换应用图标 (AppIcon.png)"
        # 使用 sips 生成不同尺寸的图标
        sips -z 16 16 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_16x16.png > /dev/null 2>&1
        sips -z 32 32 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png > /dev/null 2>&1
        sips -z 32 32 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_32x32.png > /dev/null 2>&1
        sips -z 64 64 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png > /dev/null 2>&1
        sips -z 128 128 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_128x128.png > /dev/null 2>&1
        sips -z 256 256 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png > /dev/null 2>&1
        sips -z 256 256 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_256x256.png > /dev/null 2>&1
        sips -z 512 512 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png > /dev/null 2>&1
        sips -z 512 512 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_512x512.png > /dev/null 2>&1
        sips -z 1024 1024 custom_icons/AppIcon.png --out SiteBox/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png > /dev/null 2>&1
    fi

    # 替换菜单栏图标
    if [ -f "custom_icons/StatusBarIcon.png" ]; then
        echo "   ✓ 替换菜单栏图标 (StatusBarIcon.png)"
        # 生成 1x 版本 (18x18)
        sips -z 18 18 custom_icons/StatusBarIcon.png --out SiteBox/Assets.xcassets/StatusBarIcon.imageset/18_logo.png > /dev/null 2>&1
        # 生成 2x 版本 (36x36)
        sips -z 36 36 custom_icons/StatusBarIcon.png --out SiteBox/Assets.xcassets/StatusBarIcon.imageset/36_logo.png > /dev/null 2>&1
        # 生成 3x 版本 (54x54)
        sips -z 54 54 custom_icons/StatusBarIcon.png --out SiteBox/Assets.xcassets/StatusBarIcon.imageset/54_logo.png > /dev/null 2>&1
    fi

    echo ""
fi

# 清理旧的构建
echo "1️⃣ 清理旧的构建..."
xcodebuild clean -project SiteBox.xcodeproj -target SiteBox -configuration Release > /dev/null 2>&1

# 构建 Release 版本（通用二进制：支持 Apple Silicon 和 Intel）
echo "2️⃣ 构建 Release 版本（通用二进制）..."
xcodebuild -project SiteBox.xcodeproj -target SiteBox -configuration Release -arch x86_64 -arch arm64 build ONLY_ACTIVE_ARCH=NO

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 构建成功！"
    echo ""

    # 查找应用
    APP_PATH="build/Release/SiteBox.app"

    if [ -d "$APP_PATH" ]; then
        # 验证架构
        echo "🔍 验证架构..."
        ARCH_INFO=$(lipo -info "$APP_PATH/Contents/MacOS/SiteBox" 2>/dev/null)
        if [[ $ARCH_INFO == *"x86_64"* ]] && [[ $ARCH_INFO == *"arm64"* ]]; then
            echo "✅ 通用二进制：支持 Intel (x86_64) 和 Apple Silicon (arm64)"
        else
            echo "⚠️  架构信息：$ARCH_INFO"
        fi
        echo ""

        echo "📦 应用位置: $APP_PATH"
        echo ""
        echo "📋 安装步骤："
        echo "   1. 打开 Finder"
        echo "   2. 将 SiteBox.app 拖到 /Applications 文件夹"
        echo "   3. 双击运行"
        echo ""

        # 询问是否自动安装
        read -p "是否自动安装到 /Applications? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 删除旧版本
            rm -rf /Applications/SiteBox.app 2>/dev/null

            cp -R "$APP_PATH" /Applications/
            echo "✅ 已安装到 /Applications/SiteBox.app"
            echo ""
            echo "🎉 可以在启动台找到应用了！"
        fi

        # 打开应用所在文件夹
        open "$(dirname "$APP_PATH")"
    else
        echo "❌ 未找到构建产物"
    fi
else
    echo "❌ 构建失败"
    exit 1
fi


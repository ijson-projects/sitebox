#!/bin/bash

# SiteBox 完全卸载脚本
# 删除应用、缓存、配置文件和所有相关数据

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 应用信息
APP_NAME="SiteBox"
BUNDLE_ID="com.ijson.SiteBox"
APP_PATH="/Applications/${APP_NAME}.app"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 显示将要删除的内容
show_uninstall_info() {
    print_header "SiteBox 完全卸载"
    
    echo "将要删除以下内容："
    echo ""
    echo "📦 应用程序："
    echo "   • ${APP_PATH}"
    echo ""
    echo "🗂️  配置文件："
    echo "   • ~/Library/Preferences/${BUNDLE_ID}.plist"
    echo ""
    echo "💾 缓存数据："
    echo "   • ~/Library/Caches/${BUNDLE_ID}"
    echo "   • ~/Library/WebKit/${BUNDLE_ID}"
    echo ""
    echo "🌐 网站数据："
    echo "   • ~/Library/Containers/${BUNDLE_ID}"
    echo ""
    echo "📝 日志文件："
    echo "   • ~/Library/Logs/${BUNDLE_ID}"
    echo ""
    echo "🔧 应用支持文件："
    echo "   • ~/Library/Application Support/${BUNDLE_ID}"
    echo ""
    echo "🍪 Cookies 和会话："
    echo "   • ~/Library/Cookies/${BUNDLE_ID}"
    echo "   • ~/Library/Saved Application State/${BUNDLE_ID}.savedState"
    echo ""
}

# 确认卸载
confirm_uninstall() {
    print_warning "此操作将完全删除 ${APP_NAME} 及其所有数据，无法恢复！"
    echo ""
    read -p "确定要继续吗？(yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "已取消卸载"
        exit 0
    fi
}

# 关闭正在运行的应用
kill_app() {
    print_info "检查应用是否正在运行..."
    
    if pgrep -x "${APP_NAME}" > /dev/null; then
        print_warning "应用正在运行，正在关闭..."
        killall "${APP_NAME}" 2>/dev/null || true
        sleep 1
        
        # 强制关闭
        if pgrep -x "${APP_NAME}" > /dev/null; then
            killall -9 "${APP_NAME}" 2>/dev/null || true
            sleep 1
        fi
        
        print_success "应用已关闭"
    else
        print_info "应用未运行"
    fi
}

# 删除应用程序
remove_app() {
    print_info "删除应用程序..."
    
    if [ -d "${APP_PATH}" ]; then
        rm -rf "${APP_PATH}"
        print_success "已删除: ${APP_PATH}"
    else
        print_warning "应用程序不存在: ${APP_PATH}"
    fi
}

# 删除配置文件
remove_preferences() {
    print_info "删除配置文件..."
    
    local plist_path="${HOME}/Library/Preferences/${BUNDLE_ID}.plist"
    if [ -f "${plist_path}" ]; then
        rm -f "${plist_path}"
        print_success "已删除: ${plist_path}"
    else
        print_warning "配置文件不存在"
    fi
    
    # 清除 defaults 缓存
    defaults delete "${BUNDLE_ID}" 2>/dev/null || true
}

# 删除缓存
remove_caches() {
    print_info "删除缓存数据..."
    
    local cache_paths=(
        "${HOME}/Library/Caches/${BUNDLE_ID}"
        "${HOME}/Library/WebKit/${BUNDLE_ID}"
    )
    
    for path in "${cache_paths[@]}"; do
        if [ -d "${path}" ]; then
            rm -rf "${path}"
            print_success "已删除: ${path}"
        fi
    done
}

# 删除容器数据
remove_container_data() {
    print_info "删除容器数据（网站数据、Cookie、本地存储）..."

    local container_path="${HOME}/Library/Containers/${BUNDLE_ID}"
    if [ -d "${container_path}" ]; then
        rm -rf "${container_path}"
        print_success "已删除: ${container_path}"
    else
        print_warning "容器数据不存在"
    fi
}

# 删除日志文件
remove_logs() {
    print_info "删除日志文件..."

    local log_path="${HOME}/Library/Logs/${BUNDLE_ID}"
    if [ -d "${log_path}" ]; then
        rm -rf "${log_path}"
        print_success "已删除: ${log_path}"
    else
        print_warning "日志文件不存在"
    fi
}

# 删除应用支持文件
remove_application_support() {
    print_info "删除应用支持文件..."

    local support_path="${HOME}/Library/Application Support/${BUNDLE_ID}"
    if [ -d "${support_path}" ]; then
        rm -rf "${support_path}"
        print_success "已删除: ${support_path}"
    else
        print_warning "应用支持文件不存在"
    fi
}

# 删除 Cookies 和会话
remove_cookies_and_sessions() {
    print_info "删除 Cookies 和会话数据..."

    local paths=(
        "${HOME}/Library/Cookies/${BUNDLE_ID}"
        "${HOME}/Library/Saved Application State/${BUNDLE_ID}.savedState"
    )

    for path in "${paths[@]}"; do
        if [ -e "${path}" ]; then
            rm -rf "${path}"
            print_success "已删除: ${path}"
        fi
    done
}

# 删除其他可能的文件
remove_other_files() {
    print_info "删除其他相关文件..."

    local other_paths=(
        "${HOME}/Library/HTTPStorages/${BUNDLE_ID}"
        "${HOME}/Library/HTTPStorages/${BUNDLE_ID}.binarycookies"
        "${HOME}/Library/WebKit/com.apple.WebKit.WebContent/${BUNDLE_ID}"
    )

    for path in "${other_paths[@]}"; do
        if [ -e "${path}" ]; then
            rm -rf "${path}"
            print_success "已删除: ${path}"
        fi
    done
}

# 计算释放的空间
calculate_freed_space() {
    print_header "卸载完成"

    print_success "SiteBox 已完全卸载！"
    echo ""
    print_info "已删除所有应用数据、缓存和配置文件"
    echo ""
}

# 显示卸载后的清理建议
show_cleanup_suggestions() {
    echo "💡 额外清理建议："
    echo ""
    echo "1. 清空废纸篓以释放磁盘空间（推荐使用 Finder）："
    echo "   • 打开 Finder → 右键废纸篓 → 清空废纸篓"
    echo "   • 或使用命令: osascript -e 'tell application \"Finder\" to empty trash'"
    echo ""
    echo "2. 如果使用了自定义图标，可以删除："
    echo "   rm -rf custom_icons/"
    echo ""
    echo "3. 如果不再需要源代码，可以删除整个项目目录"
    echo ""
    echo "⚠️  注意: 不建议使用 'rm -rf ~/.Trash/*'，这会永久删除所有废纸篓文件"
    echo ""
}

# 主函数
main() {
    # 检查是否在正确的目录
    if [ ! -f "package.sh" ] && [ ! -f "uninstall.sh" ]; then
        print_error "请在 SiteBox 项目目录中运行此脚本"
        exit 1
    fi

    # 显示卸载信息
    show_uninstall_info

    # 确认卸载
    confirm_uninstall

    print_header "开始卸载"

    # 执行卸载步骤
    kill_app
    echo ""

    remove_app
    echo ""

    remove_preferences
    echo ""

    remove_caches
    echo ""

    remove_container_data
    echo ""

    remove_logs
    echo ""

    remove_application_support
    echo ""

    remove_cookies_and_sessions
    echo ""

    remove_other_files
    echo ""

    # 显示完成信息
    calculate_freed_space

    # 显示清理建议
    show_cleanup_suggestions

    print_success "卸载脚本执行完成！"
}

# 运行主函数
main "$@"



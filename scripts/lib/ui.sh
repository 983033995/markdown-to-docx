#!/bin/bash
# UI 函数库 - 提供统一的用户界面组件
# 包括进度条、彩色输出、图标等

# 颜色定义
export UI_RED='\033[0;31m'
export UI_GREEN='\033[0;32m'
export UI_YELLOW='\033[1;33m'
export UI_BLUE='\033[0;34m'
export UI_CYAN='\033[0;36m'
export UI_MAGENTA='\033[0;35m'
export UI_BOLD='\033[1m'
export UI_NC='\033[0m'

# 图标定义
export UI_ICON_SUCCESS="✓"
export UI_ICON_ERROR="✗"
export UI_ICON_WARNING="⚠"
export UI_ICON_INFO="ℹ"
export UI_ICON_PROCESSING="⟳"
export UI_ICON_ARROW="→"

# 旋转动画帧
UI_SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
UI_SPINNER_PID=""
UI_SPINNER_INDEX=0

# ============================================
# 基础输出函数
# ============================================

# 成功消息
ui_success() {
    echo -e "${UI_GREEN}${UI_ICON_SUCCESS}${UI_NC} $*"
}

# 错误消息
ui_error() {
    echo -e "${UI_RED}${UI_ICON_ERROR}${UI_NC} $*" >&2
}

# 警告消息
ui_warning() {
    echo -e "${UI_YELLOW}${UI_ICON_WARNING}${UI_NC} $*"
}

# 信息消息
ui_info() {
    echo -e "${UI_CYAN}${UI_ICON_INFO}${UI_NC} $*"
}

# 处理中消息
ui_processing() {
    echo -e "${UI_CYAN}${UI_ICON_PROCESSING}${UI_NC} $*"
}

# 标题
ui_header() {
    local title="$1"
    local width=60
    echo ""
    echo -e "${UI_BLUE}${UI_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${UI_NC}"
    echo -e "${UI_BLUE}${UI_BOLD}  $title${UI_NC}"
    echo -e "${UI_BLUE}${UI_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${UI_NC}"
    echo ""
}

# 分隔线
ui_separator() {
    echo -e "${UI_BLUE}────────────────────────────────────────────────────────────${UI_NC}"
}

# ============================================
# 进度条函数
# ============================================

# 绘制进度条
# 参数: current total [message]
ui_progress_bar() {
    local current=$1
    local total=$2
    local message="${3:-}"
    
    # 计算百分比
    local percent=$((current * 100 / total))
    
    # 进度条宽度
    local bar_width=30
    local filled=$((current * bar_width / total))
    local empty=$((bar_width - filled))
    
    # 构建进度条
    local bar="["
    for ((i=0; i<filled; i++)); do
        bar+="="
    done
    if [ $filled -lt $bar_width ]; then
        bar+=">"
    fi
    for ((i=0; i<empty-1; i++)); do
        bar+=" "
    done
    bar+="]"
    
    # 输出进度
    printf "\r${UI_CYAN}${bar} ${UI_BOLD}%3d%%${UI_NC} ${UI_CYAN}(%d/%d)${UI_NC} %s" \
        "$percent" "$current" "$total" "$message"
    
    # 完成时换行
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# 简单进度显示
# 参数: current total message
ui_progress_simple() {
    local current=$1
    local total=$2
    local message="$3"
    
    local percent=$((current * 100 / total))
    echo -e "${UI_CYAN}[${current}/${total}]${UI_NC} ${UI_BOLD}${percent}%${UI_NC} ${UI_ICON_ARROW} ${message}"
}

# ============================================
# 旋转动画
# ============================================

# 启动旋转动画
# 参数: message
ui_spinner_start() {
    local message="$1"
    
    # 后台运行旋转动画
    (
        while true; do
            for frame in "${UI_SPINNER_FRAMES[@]}"; do
                printf "\r${UI_CYAN}${frame}${UI_NC} ${message}"
                sleep 0.1
            done
        done
    ) &
    
    UI_SPINNER_PID=$!
    
    # 禁用光标
    tput civis 2>/dev/null || true
}

# 停止旋转动画
# 参数: final_message [success|error|warning]
ui_spinner_stop() {
    local final_message="$1"
    local status="${2:-success}"
    
    # 停止后台进程
    if [ -n "$UI_SPINNER_PID" ]; then
        kill "$UI_SPINNER_PID" 2>/dev/null || true
        wait "$UI_SPINNER_PID" 2>/dev/null || true
        UI_SPINNER_PID=""
    fi
    
    # 清除当前行
    printf "\r\033[K"
    
    # 显示最终消息
    case "$status" in
        success)
            ui_success "$final_message"
            ;;
        error)
            ui_error "$final_message"
            ;;
        warning)
            ui_warning "$final_message"
            ;;
        *)
            ui_info "$final_message"
            ;;
    esac
    
    # 恢复光标
    tput cnorm 2>/dev/null || true
}

# ============================================
# 步骤显示
# ============================================

# 显示步骤
# 参数: step_num total_steps message
ui_step() {
    local step_num=$1
    local total_steps=$2
    local message="$3"
    
    echo -e "${UI_YELLOW}[${step_num}/${total_steps}]${UI_NC} ${UI_BOLD}${message}${UI_NC}"
}

# ============================================
# 确认对话框
# ============================================

# 询问用户确认
# 参数: question [default_yes]
# 返回: 0=yes, 1=no
ui_confirm() {
    local question="$1"
    local default_yes="${2:-false}"
    
    local prompt
    if [ "$default_yes" = true ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    echo -ne "${UI_CYAN}${UI_ICON_INFO}${UI_NC} ${question} ${prompt}: "
    read -r response
    
    # 处理默认值
    if [ -z "$response" ]; then
        [ "$default_yes" = true ] && return 0 || return 1
    fi
    
    # 检查响应
    case "${response,,}" in
        y|yes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================
# 错误处理
# ============================================

# 显示错误并退出
# 参数: error_message [exit_code]
ui_fatal() {
    local error_message="$1"
    local exit_code="${2:-1}"
    
    echo ""
    ui_error "致命错误: $error_message"
    echo ""
    exit "$exit_code"
}

# 显示详细错误信息
# 参数: error_message cause solution
ui_error_detail() {
    local error_message="$1"
    local cause="$2"
    local solution="$3"
    
    echo ""
    echo -e "${UI_RED}${UI_BOLD}${UI_ICON_ERROR} 错误${UI_NC}"
    echo -e "${UI_RED}  消息: ${error_message}${UI_NC}"
    echo ""
    echo -e "${UI_YELLOW}${UI_BOLD}${UI_ICON_WARNING} 可能原因${UI_NC}"
    echo -e "${UI_YELLOW}  ${cause}${UI_NC}"
    echo ""
    echo -e "${UI_CYAN}${UI_BOLD}${UI_ICON_INFO} 建议解决方案${UI_NC}"
    echo -e "${UI_CYAN}  ${solution}${UI_NC}"
    echo ""
}

# ============================================
# 文件操作显示
# ============================================

# 显示文件信息
# 参数: label value
ui_file_info() {
    local label="$1"
    local value="$2"
    
    echo -e "${UI_CYAN}${label}:${UI_NC} ${value}"
}

# 显示文件大小
# 参数: file_path
ui_file_size() {
    local file_path="$1"
    
    if [ -f "$file_path" ]; then
        local size=$(ls -lh "$file_path" | awk '{print $5}')
        echo -e "${UI_CYAN}文件大小:${UI_NC} ${size}"
    fi
}

# ============================================
# 总结框
# ============================================

# 显示成功总结
# 参数: title [key value]...
ui_summary_success() {
    local title="$1"
    shift
    
    echo ""
    echo -e "${UI_GREEN}${UI_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${UI_NC}"
    echo -e "${UI_GREEN}${UI_BOLD}  ${UI_ICON_SUCCESS} ${title}${UI_NC}"
    echo -e "${UI_GREEN}${UI_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${UI_NC}"
    echo ""
    
    while [ $# -ge 2 ]; do
        ui_file_info "$1" "$2"
        shift 2
    done
    
    echo ""
}

# ============================================
# 清理函数
# ============================================

# 清理 UI 资源
ui_cleanup() {
    # 停止旋转动画
    if [ -n "$UI_SPINNER_PID" ]; then
        kill "$UI_SPINNER_PID" 2>/dev/null || true
        wait "$UI_SPINNER_PID" 2>/dev/null || true
    fi
    
    # 恢复光标
    tput cnorm 2>/dev/null || true
}

# 注册清理函数
trap ui_cleanup EXIT INT TERM

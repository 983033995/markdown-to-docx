#!/bin/bash

# Markdown to DOCX 批量转换脚本
# 支持批量转换多个 Markdown 文件

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERT_SCRIPT="$SCRIPT_DIR/convert.sh"

# 加载 UI 库
source "$SCRIPT_DIR/lib/ui.sh"

# 使用说明
usage() {
    echo "用法: $0 <markdown文件1> [markdown文件2] [markdown文件3] ..."
    echo ""
    echo "参数:"
    echo "  <markdown文件>  要转换的 Markdown 文件路径(可以指定多个)"
    echo ""
    echo "示例:"
    echo "  $0 doc1.md doc2.md doc3.md"
    echo "  $0 /path/to/*.md"
    exit 1
}

# 检查参数
if [ $# -lt 1 ]; then
    usage
fi

# 检查转换脚本
if [ ! -f "$CONVERT_SCRIPT" ]; then
    ui_fatal "未找到转换脚本: $CONVERT_SCRIPT"
fi

# 统计信息
TOTAL_FILES=$#
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FILES=()

ui_header "批量转换 Markdown → DOCX"
ui_info "总文件数: $TOTAL_FILES"
echo ""

# 遍历所有文件
CURRENT=0
for INPUT_FILE in "$@"; do
    CURRENT=$((CURRENT + 1))
    
    # 显示进度
    ui_progress_bar "$CURRENT" "$TOTAL_FILES" "$(basename "$INPUT_FILE")"
    
    # 检查文件是否存在
    if [ ! -f "$INPUT_FILE" ]; then
        ui_warning "文件不存在,跳过: $INPUT_FILE"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_FILES+=("$INPUT_FILE (文件不存在)")
        continue
    fi
    
    # 检查文件扩展名
    if [[ ! "$INPUT_FILE" =~ \.md$ ]] && [[ ! "$INPUT_FILE" =~ \.markdown$ ]]; then
        ui_warning "非 Markdown 文件,跳过: $INPUT_FILE"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_FILES+=("$INPUT_FILE (非 Markdown 文件)")
        continue
    fi
    
    # 执行转换
    if "$CONVERT_SCRIPT" "$INPUT_FILE" > /dev/null 2>&1; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_FILES+=("$INPUT_FILE")
    fi
done

echo ""

# 显示统计结果
if [ $FAIL_COUNT -eq 0 ]; then
    ui_summary_success "转换完成" \
        "总文件数" "$TOTAL_FILES" \
        "成功" "$SUCCESS_COUNT" \
        "失败" "$FAIL_COUNT"
else
    ui_header "转换完成"
    ui_file_info "总文件数" "$TOTAL_FILES"
    ui_success "成功: $SUCCESS_COUNT"
    ui_error "失败: $FAIL_COUNT"
    echo ""
    
    # 显示失败文件列表
    ui_error "失败文件列表:"
    for FAILED_FILE in "${FAILED_FILES[@]}"; do
        echo "  - $FAILED_FILE"
    done
    echo ""
fi

# 返回状态码
if [ $FAIL_COUNT -eq 0 ]; then
    exit 0
else
    exit 1
fi

#!/bin/bash

# Markdown to DOCX 批量转换脚本
# 支持批量转换多个 Markdown 文件

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERT_SCRIPT="$SCRIPT_DIR/convert.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${RED}错误: 未找到转换脚本: $CONVERT_SCRIPT${NC}"
    exit 1
fi

# 统计信息
TOTAL_FILES=$#
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FILES=()

echo -e "${BLUE}======================================"
echo "  批量转换 Markdown to DOCX"
echo "======================================${NC}"
echo "总文件数: $TOTAL_FILES"
echo ""

# 遍历所有文件
CURRENT=0
for INPUT_FILE in "$@"; do
    CURRENT=$((CURRENT + 1))
    
    echo -e "${BLUE}[$CURRENT/$TOTAL_FILES] 处理: $INPUT_FILE${NC}"
    
    # 检查文件是否存在
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}  ✗ 文件不存在,跳过${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_FILES+=("$INPUT_FILE (文件不存在)")
        echo ""
        continue
    fi
    
    # 检查文件扩展名
    if [[ ! "$INPUT_FILE" =~ \.md$ ]] && [[ ! "$INPUT_FILE" =~ \.markdown$ ]]; then
        echo -e "${YELLOW}  ⚠ 不是 Markdown 文件,跳过${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_FILES+=("$INPUT_FILE (非 Markdown 文件)")
        echo ""
        continue
    fi
    
    # 执行转换
    if "$CONVERT_SCRIPT" "$INPUT_FILE" > /dev/null 2>&1; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo -e "${GREEN}  ✓ 转换成功${NC}"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_FILES+=("$INPUT_FILE")
        echo -e "${RED}  ✗ 转换失败${NC}"
    fi
    
    echo ""
done

# 显示统计结果
echo -e "${BLUE}======================================"
echo "  转换完成"
echo "======================================${NC}"
echo -e "总文件数: $TOTAL_FILES"
echo -e "${GREEN}成功: $SUCCESS_COUNT${NC}"
echo -e "${RED}失败: $FAIL_COUNT${NC}"

# 显示失败文件列表
if [ $FAIL_COUNT -gt 0 ]; then
    echo ""
    echo -e "${RED}失败文件列表:${NC}"
    for FAILED_FILE in "${FAILED_FILES[@]}"; do
        echo "  - $FAILED_FILE"
    done
fi

echo ""

# 返回状态码
if [ $FAIL_COUNT -eq 0 ]; then
    exit 0
else
    exit 1
fi

#!/bin/bash

# Markdown to DOCX 转换脚本
# 支持 Mermaid 图表、LaTeX 公式、代码高亮、表格、图片、脚注等

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FILTER_DIR="$PROJECT_DIR/filters"
TEMPLATE_DIR="$PROJECT_DIR/templates"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 使用说明
usage() {
    echo "用法: $0 <markdown文件> [输出文件]"
    echo ""
    echo "参数:"
    echo "  <markdown文件>  要转换的 Markdown 文件路径"
    echo "  [输出文件]      可选,输出的 DOCX 文件路径"
    echo "                  如果不指定,将在源文件同目录生成同名 .docx 文件"
    echo ""
    echo "示例:"
    echo "  $0 document.md"
    echo "  $0 document.md output.docx"
    echo "  $0 /path/to/document.md /path/to/output.docx"
    exit 1
}

# 检查参数
if [ $# -lt 1 ]; then
    usage
fi

INPUT_FILE="$1"

# 检查输入文件是否存在
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}错误: 文件不存在: $INPUT_FILE${NC}"
    exit 1
fi

# 确定输出文件路径
if [ $# -ge 2 ]; then
    OUTPUT_FILE="$2"
else
    # 在源文件同目录生成同名 .docx 文件
    INPUT_DIR="$(dirname "$INPUT_FILE")"
    INPUT_BASENAME="$(basename "$INPUT_FILE" .md)"
    OUTPUT_FILE="$INPUT_DIR/$INPUT_BASENAME.docx"
fi

# 检查必要工具
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}错误: 未找到 $1${NC}"
        echo "请运行 $PROJECT_DIR/scripts/check_dependencies.sh 安装依赖"
        exit 1
    fi
}

echo -e "${BLUE}检查依赖工具...${NC}"
check_tool pandoc
check_tool mmdc

# 检查 Lua 过滤器
if [ ! -f "$FILTER_DIR/mermaid.lua" ]; then
    echo -e "${RED}错误: 未找到 Mermaid 过滤器: $FILTER_DIR/mermaid.lua${NC}"
    exit 1
fi

# 检查模板文件
REFERENCE_DOCX="$TEMPLATE_DIR/reference.docx"
REFERENCE_ARG=""
if [ -f "$REFERENCE_DOCX" ]; then
    REFERENCE_ARG="--reference-doc=$REFERENCE_DOCX"
    echo -e "${GREEN}使用自定义模板: $REFERENCE_DOCX${NC}"
else
    echo -e "${YELLOW}未找到自定义模板,使用 Pandoc 默认样式${NC}"
fi

# 开始转换
echo -e "${BLUE}开始转换...${NC}"
echo "  输入: $INPUT_FILE"
echo "  输出: $OUTPUT_FILE"
echo ""

# Pandoc 转换命令
# 参数说明:
# -f markdown: 输入格式为 Markdown
# -t docx: 输出格式为 DOCX
# --lua-filter: 使用 Lua 过滤器处理 Mermaid
# --mathml: 将 LaTeX 数学公式转换为 MathML
# --toc: 生成目录 (可选)
# --reference-doc: 使用自定义模板

pandoc "$INPUT_FILE" \
    -f markdown \
    -t docx \
    --lua-filter="$FILTER_DIR/mermaid.lua" \
    --mathml \
    $REFERENCE_ARG \
    -o "$OUTPUT_FILE" \
    2>&1

# 检查转换结果
if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
    echo ""
    echo -e "${GREEN}✓ 转换成功!${NC}"
    echo "  输出文件: $OUTPUT_FILE"
    echo "  文件大小: $FILE_SIZE"
    exit 0
else
    echo ""
    echo -e "${RED}✗ 转换失败${NC}"
    exit 1
fi

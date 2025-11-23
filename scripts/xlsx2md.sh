#!/bin/bash
# Excel 转 Markdown 表格转换脚本
# 支持单 sheet 和多 sheet 转换

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMP_DIR=$(mktemp -d)

# 清理函数
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# 使用说明
usage() {
    cat << EOF
${BLUE}${BOLD}Excel 转 Markdown 表格工具${NC}

${CYAN}用法:${NC}
    $0 [选项] <excel文件> [输出文件]

${CYAN}选项:${NC}
    -s, --sheet SHEET     指定要转换的 sheet 名称或索引(从1开始)
    -a, --all-sheets      转换所有 sheet(默认)
    -h, --help            显示帮助信息

${CYAN}参数:${NC}
    <excel文件>           要转换的 Excel 文件(.xlsx)
    [输出文件]            可选,输出的 Markdown 文件路径
                          默认: <输入文件名>.md

${CYAN}示例:${NC}
    # 转换所有 sheet
    $0 data.xlsx

    # 转换指定 sheet
    $0 -s 1 data.xlsx
    $0 -s "销售数据" data.xlsx output.md

${CYAN}说明:${NC}
    - 默认转换所有 sheet,每个 sheet 生成一个二级标题
    - 支持按 sheet 名称或索引选择
    - 自动格式化为 Markdown 表格
    - 保留表头行

EOF
    exit 0
}

# 解析参数
SHEET_NAME=""
ALL_SHEETS=true
INPUT_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -s|--sheet)
            SHEET_NAME="$2"
            ALL_SHEETS=false
            shift 2
            ;;
        -a|--all-sheets)
            ALL_SHEETS=true
            shift
            ;;
        -*)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            usage
            ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            elif [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE="$1"
            else
                echo -e "${RED}错误: 参数过多${NC}"
                usage
            fi
            shift
            ;;
    esac
done

# 检查输入文件
if [ -z "$INPUT_FILE" ]; then
    echo -e "${RED}错误: 未指定输入文件${NC}"
    usage
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}错误: 文件不存在: $INPUT_FILE${NC}"
    exit 1
fi

# 确定输出文件
if [ -z "$OUTPUT_FILE" ]; then
    INPUT_DIR="$(dirname "$INPUT_FILE")"
    INPUT_BASENAME="$(basename "$INPUT_FILE" .xlsx)"
    OUTPUT_FILE="$INPUT_DIR/$INPUT_BASENAME.md"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Excel → Markdown 表格转换${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}输入文件:${NC} $INPUT_FILE"
echo -e "${CYAN}输出文件:${NC} $OUTPUT_FILE"
echo ""

# 检查 openpyxl
if ! python3 -c "import openpyxl" 2>/dev/null; then
    echo -e "${RED}错误: 未安装 openpyxl${NC}"
    echo "请运行: pip3 install --break-system-packages openpyxl"
    exit 1
fi

# 读取 Excel 并转换为 Markdown
echo -e "${YELLOW}[1/3]${NC} 读取 Excel 文件..."

CONVERT_SCRIPT="$TEMP_DIR/xlsx_to_md.py"
cat > "$CONVERT_SCRIPT" << 'PYTHON_EOF'
import sys
from openpyxl import load_workbook

def excel_to_markdown(excel_file, sheet_name=None, all_sheets=True):
    """将 Excel 转换为 Markdown"""
    wb = load_workbook(excel_file, data_only=True)
    
    markdown_content = []
    
    if all_sheets:
        # 转换所有 sheet
        for sheet in wb.worksheets:
            md_table = convert_sheet_to_markdown(sheet, sheet.title)
            if md_table:
                markdown_content.append(md_table)
    else:
        # 转换指定 sheet
        if sheet_name.isdigit():
            # 按索引
            sheet_index = int(sheet_name) - 1
            if 0 <= sheet_index < len(wb.worksheets):
                sheet = wb.worksheets[sheet_index]
                md_table = convert_sheet_to_markdown(sheet, sheet.title)
                if md_table:
                    markdown_content.append(md_table)
            else:
                print(f"错误: Sheet 索引 {sheet_name} 超出范围", file=sys.stderr)
                return None
        else:
            # 按名称
            if sheet_name in wb.sheetnames:
                sheet = wb[sheet_name]
                md_table = convert_sheet_to_markdown(sheet, sheet.title)
                if md_table:
                    markdown_content.append(md_table)
            else:
                print(f"错误: 未找到 Sheet '{sheet_name}'", file=sys.stderr)
                return None
    
    return '\n\n'.join(markdown_content)

def convert_sheet_to_markdown(sheet, title):
    """将单个 sheet 转换为 Markdown 表格"""
    # 读取所有行
    rows = list(sheet.iter_rows(values_only=True))
    
    if not rows:
        return None
    
    # 过滤空行
    rows = [row for row in rows if any(cell is not None for cell in row)]
    
    if not rows:
        return None
    
    # 构建 Markdown
    md_lines = []
    
    # 添加标题
    md_lines.append(f"## {title}")
    md_lines.append("")
    
    # 表头
    header = rows[0]
    header_str = "| " + " | ".join(str(cell) if cell is not None else "" for cell in header) + " |"
    md_lines.append(header_str)
    
    # 分隔线
    separator = "|" + "|".join("---" for _ in header) + "|"
    md_lines.append(separator)
    
    # 数据行
    for row in rows[1:]:
        row_str = "| " + " | ".join(str(cell) if cell is not None else "" for cell in row) + " |"
        md_lines.append(row_str)
    
    return '\n'.join(md_lines)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("用法: python xlsx_to_md.py <excel_file> <all_sheets> [sheet_name]", file=sys.stderr)
        sys.exit(1)
    
    excel_file = sys.argv[1]
    all_sheets = sys.argv[2].lower() == 'true'
    sheet_name = sys.argv[3] if len(sys.argv) > 3 else None
    
    markdown = excel_to_markdown(excel_file, sheet_name, all_sheets)
    
    if markdown:
        print(markdown)
    else:
        sys.exit(1)
PYTHON_EOF

# 执行转换
SHEET_ARG="$SHEET_NAME"
if [ "$ALL_SHEETS" = true ]; then
    SHEET_ARG=""
fi

if python3 "$CONVERT_SCRIPT" "$INPUT_FILE" "$ALL_SHEETS" "$SHEET_ARG" > "$OUTPUT_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} 读取完成"
    echo ""
    echo -e "${YELLOW}[2/3]${NC} 生成 Markdown..."
    echo -e "${GREEN}✓${NC} 生成完成"
    echo ""
    echo -e "${YELLOW}[3/3]${NC} 完成"
    echo ""
    
    FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
    LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ 转换成功!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}输出文件:${NC} $OUTPUT_FILE"
    echo -e "${CYAN}文件大小:${NC} $FILE_SIZE"
    echo -e "${CYAN}行数:${NC} $LINE_COUNT"
    echo ""
else
    echo -e "${RED}错误: 转换失败${NC}"
    exit 1
fi

#!/bin/bash
# Markdown 表格转 Excel 转换脚本
# 支持单表格和多表格(多 sheet)转换

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
${BLUE}${BOLD}Markdown 表格转 Excel 工具${NC}

${CYAN}用法:${NC}
    $0 [选项] <markdown文件> [输出文件]

${CYAN}选项:${NC}
    -s, --single-sheet    强制单 sheet 模式(合并所有表格)
    -m, --multi-sheet     多 sheet 模式(每个表格一个 sheet)
    -h, --help            显示帮助信息

${CYAN}参数:${NC}
    <markdown文件>        要转换的 Markdown 文件
    [输出文件]            可选,输出的 Excel 文件路径
                          默认: <输入文件名>.xlsx

${CYAN}示例:${NC}
    # 自动检测模式(默认)
    $0 document.md

    # 强制多 sheet 模式
    $0 -m document.md output.xlsx

    # 强制单 sheet 模式
    $0 -s document.md

${CYAN}说明:${NC}
    - 自动检测表格数量,单表格用单 sheet,多表格用多 sheet
    - 支持表格标题作为 sheet 名称
    - 保留表格对齐方式
    - 自动格式化表头(加粗)

EOF
    exit 0
}

# 解析参数
MODE="auto"  # auto, single, multi
INPUT_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -s|--single-sheet)
            MODE="single"
            shift
            ;;
        -m|--multi-sheet)
            MODE="multi"
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
    INPUT_BASENAME="$(basename "$INPUT_FILE" .md)"
    OUTPUT_FILE="$INPUT_DIR/$INPUT_BASENAME.xlsx"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Markdown 表格 → Excel 转换${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}输入文件:${NC} $INPUT_FILE"
echo -e "${CYAN}输出文件:${NC} $OUTPUT_FILE"
echo ""

# 检查 Pandoc
if ! command -v pandoc &> /dev/null; then
    echo -e "${RED}错误: 未找到 pandoc${NC}"
    echo "请运行 $PROJECT_DIR/scripts/check_dependencies.sh 安装依赖"
    exit 1
fi

# 提取表格信息
echo -e "${YELLOW}[1/4]${NC} 分析 Markdown 文件..."

# 使用 Pandoc 提取表格为 JSON
TABLES_JSON="$TEMP_DIR/tables.json"
pandoc "$INPUT_FILE" -t json -o "$TABLES_JSON" 2>/dev/null

# 使用 Python 解析表格
PYTHON_SCRIPT="$TEMP_DIR/extract_tables.py"
cat > "$PYTHON_SCRIPT" << 'PYTHON_EOF'
import json
import sys
import re

def extract_tables(json_file):
    """从 Pandoc JSON 中提取表格"""
    with open(json_file, 'r') as f:
        doc = json.load(f)
    
    tables = []
    current_heading = "Sheet1"
    heading_counter = {}
    
    def walk_blocks(blocks):
        nonlocal current_heading
        for block in blocks:
            # 检测标题
            if block.get('t') == 'Header':
                level = block['c'][0]
                content = block['c'][2]
                # 提取标题文本
                heading_text = ''.join([
                    item['c'] if item.get('t') == 'Str' else ' '
                    for item in content
                    if item.get('t') in ['Str', 'Space']
                ]).strip()
                
                if heading_text:
                    current_heading = heading_text
                    # 确保 sheet 名称唯一
                    if current_heading in heading_counter:
                        heading_counter[current_heading] += 1
                        current_heading = f"{heading_text}_{heading_counter[current_heading]}"
                    else:
                        heading_counter[current_heading] = 1
            
            # 检测表格
            elif block.get('t') == 'Table':
                table_data = parse_table(block)
                if table_data:
                    tables.append({
                        'sheet_name': current_heading,
                        'data': table_data
                    })
    
    def parse_table(table_block):
        """解析表格块"""
        try:
            # Pandoc 表格结构: [attr, caption, colspecs, head, bodies, foot]
            caption = table_block['c'][1]
            head = table_block['c'][3]
            bodies = table_block['c'][4]
            
            rows = []
            
            # 解析表头
            if head and head[1]:  # [attr, rows]
                for row in head[1]:
                    row_data = parse_row(row)
                    if row_data:
                        rows.append(row_data)
            
            # 解析表体
            for body in bodies:
                # body: [attr, row_head_columns, head_rows, body_rows]
                body_rows = body[3]
                for row in body_rows:
                    row_data = parse_row(row)
                    if row_data:
                        rows.append(row_data)
            
            return rows
        except Exception as e:
            print(f"警告: 解析表格失败: {e}", file=sys.stderr)
            return None
    
    def parse_row(row):
        """解析表格行"""
        try:
            # row: [attr, cells]
            cells = row[1]
            row_data = []
            
            for cell in cells:
                # cell: [attr, alignment, rowspan, colspan, blocks]
                blocks = cell[4]
                cell_text = extract_text(blocks)
                row_data.append(cell_text)
            
            return row_data
        except Exception as e:
            print(f"警告: 解析行失败: {e}", file=sys.stderr)
            return None
    
    def extract_text(blocks):
        """从块中提取文本"""
        text_parts = []
        for block in blocks:
            if block.get('t') == 'Para' or block.get('t') == 'Plain':
                for inline in block.get('c', []):
                    if inline.get('t') == 'Str':
                        text_parts.append(inline['c'])
                    elif inline.get('t') == 'Space':
                        text_parts.append(' ')
                    elif inline.get('t') == 'Code':
                        text_parts.append(inline['c'][1])
        return ''.join(text_parts).strip()
    
    # 遍历文档
    walk_blocks(doc['blocks'])
    
    return tables

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("用法: python extract_tables.py <json_file>", file=sys.stderr)
        sys.exit(1)
    
    tables = extract_tables(sys.argv[1])
    
    # 输出为 JSON
    print(json.dumps(tables, ensure_ascii=False, indent=2))
PYTHON_EOF

# 执行 Python 脚本提取表格
TABLES_DATA="$TEMP_DIR/tables_data.json"
if ! python3 "$PYTHON_SCRIPT" "$TABLES_JSON" > "$TABLES_DATA" 2>/dev/null; then
    echo -e "${RED}错误: 提取表格失败${NC}"
    exit 1
fi

# 检查表格数量
TABLE_COUNT=$(python3 -c "import json; print(len(json.load(open('$TABLES_DATA'))))")

if [ "$TABLE_COUNT" -eq 0 ]; then
    echo -e "${RED}错误: 未找到表格${NC}"
    echo "请确保 Markdown 文件中包含表格"
    exit 1
fi

echo -e "${GREEN}✓${NC} 找到 ${TABLE_COUNT} 个表格"

# 确定转换模式
if [ "$MODE" = "auto" ]; then
    if [ "$TABLE_COUNT" -eq 1 ]; then
        MODE="single"
    else
        MODE="multi"
    fi
fi

echo -e "${CYAN}转换模式:${NC} $MODE sheet"
echo ""

# 生成 Excel 文件
echo -e "${YELLOW}[2/4]${NC} 生成 Excel 文件..."

# 这里需要调用 MCP Excel 服务器
# 由于无法直接在 shell 中调用 MCP,我们使用 Python 脚本
EXCEL_SCRIPT="$TEMP_DIR/create_excel.py"
cat > "$EXCEL_SCRIPT" << 'EXCEL_EOF'
import json
import sys
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, PatternFill

def create_excel(tables_file, output_file, mode):
    """创建 Excel 文件"""
    with open(tables_file, 'r') as f:
        tables = json.load(f)
    
    wb = Workbook()
    wb.remove(wb.active)  # 移除默认 sheet
    
    if mode == 'single':
        # 单 sheet 模式: 合并所有表格
        ws = wb.create_sheet('Tables')
        current_row = 1
        
        for i, table in enumerate(tables):
            if i > 0:
                current_row += 2  # 表格间空两行
            
            # 添加表格标题
            if table['sheet_name'] != 'Sheet1':
                ws.cell(current_row, 1, table['sheet_name'])
                ws.cell(current_row, 1).font = Font(bold=True, size=14)
                current_row += 1
            
            # 添加表格数据
            for row_idx, row_data in enumerate(table['data']):
                for col_idx, cell_value in enumerate(row_data):
                    cell = ws.cell(current_row + row_idx, col_idx + 1, cell_value)
                    
                    # 表头格式化
                    if row_idx == 0:
                        cell.font = Font(bold=True)
                        cell.fill = PatternFill(start_color='E0E0E0', end_color='E0E0E0', fill_type='solid')
                        cell.alignment = Alignment(horizontal='center')
            
            current_row += len(table['data'])
    
    else:
        # 多 sheet 模式: 每个表格一个 sheet
        for table in tables:
            # 清理 sheet 名称(Excel 限制)
            sheet_name = table['sheet_name'][:31]  # Excel sheet 名称最长 31 字符
            sheet_name = sheet_name.replace('/', '-').replace('\\', '-')
            
            ws = wb.create_sheet(sheet_name)
            
            # 添加表格数据
            for row_idx, row_data in enumerate(table['data']):
                for col_idx, cell_value in enumerate(row_data):
                    cell = ws.cell(row_idx + 1, col_idx + 1, cell_value)
                    
                    # 表头格式化
                    if row_idx == 0:
                        cell.font = Font(bold=True)
                        cell.fill = PatternFill(start_color='E0E0E0', end_color='E0E0E0', fill_type='solid')
                        cell.alignment = Alignment(horizontal='center')
            
            # 自动调整列宽
            for column in ws.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = min(max_length + 2, 50)
                ws.column_dimensions[column_letter].width = adjusted_width
    
    # 保存文件
    wb.save(output_file)
    print(f"✓ Excel 文件已生成: {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("用法: python create_excel.py <tables_json> <output_file> <mode>", file=sys.stderr)
        sys.exit(1)
    
    create_excel(sys.argv[1], sys.argv[2], sys.argv[3])
EXCEL_EOF

# 检查 openpyxl
if ! python3 -c "import openpyxl" 2>/dev/null; then
    echo -e "${YELLOW}警告: 未安装 openpyxl,正在安装...${NC}"
    pip3 install --user openpyxl --quiet || {
        echo -e "${RED}错误: 安装 openpyxl 失败${NC}"
        echo "请手动安装: pip3 install --user openpyxl"
        exit 1
    }
fi

# 生成 Excel
if python3 "$EXCEL_SCRIPT" "$TABLES_DATA" "$OUTPUT_FILE" "$MODE"; then
    echo ""
    echo -e "${YELLOW}[3/4]${NC} 格式化 Excel..."
    echo -e "${GREEN}✓${NC} 格式化完成"
    echo ""
    echo -e "${YELLOW}[4/4]${NC} 完成"
    echo ""
    
    FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ 转换成功!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}输出文件:${NC} $OUTPUT_FILE"
    echo -e "${CYAN}文件大小:${NC} $FILE_SIZE"
    echo -e "${CYAN}表格数量:${NC} $TABLE_COUNT"
    echo -e "${CYAN}Sheet 模式:${NC} $MODE"
    echo ""
else
    echo -e "${RED}错误: 生成 Excel 失败${NC}"
    exit 1
fi

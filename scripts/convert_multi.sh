#!/bin/bash

# Markdown 多格式转换脚本
# 支持: DOCX, PDF, HTML, PPTX, EPUB
# 支持批量转换

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FILTER_DIR="$PROJECT_DIR/filters"
TEMPLATE_DIR="$PROJECT_DIR/templates"

# 默认配置
OUTPUT_FORMAT="docx"
INPUT_FORMAT="markdown"  # 默认输入格式
USE_TEMPLATE=true
HIGHLIGHT_STYLE="github"
MATH_FORMAT="mathml"
TOC_ENABLED=false
TOC_DEPTH=3
NUMBER_SECTIONS=false
STANDALONE=true

# PDF 特定配置
PDF_ENGINE="xelatex"
PDF_MARGIN_TOP="2.5cm"
PDF_MARGIN_BOTTOM="2.5cm"
PDF_MARGIN_LEFT="2.5cm"
PDF_MARGIN_RIGHT="2.5cm"
PDF_FONTSIZE="12pt"
PDF_PAPERSIZE="a4"

# HTML 特定配置
HTML_SELF_CONTAINED=true
HTML_CSS_THEME="github"
HTML_TEMPLATE=""

# PPT 特定配置
PPT_SLIDE_LEVEL=2
PPT_INCREMENTAL=false

# 输入文件列表
INPUT_FILES=()

# 显示帮助信息
show_help() {
    cat << EOF
Markdown 多格式转换工具 (批量版)

用法:
    $0 [选项] <输入文件1> [输入文件2] ...

支持的格式:
    markdown - Markdown 文档
    docx    - Microsoft Word 文档 (默认)
    pdf     - PDF 文档
    html    - HTML 网页
    txt     - 纯文本
    pptx    - PowerPoint 演示文稿
    epub    - 电子书

选项:
    -f, --format FORMAT     输出格式 (markdown|docx|pdf|html|txt|pptx|epub)
    --no-template           不使用自定义模板
    --toc                   生成目录
    --toc-depth N           目录深度 (默认: 3)
    --number-sections       章节编号
    
    PDF 选项:
    --pdf-engine ENGINE     PDF 引擎 (xelatex|pdflatex|lualatex)
    --margin-top SIZE       上边距 (默认: 2.5cm)
    --margin-bottom SIZE    下边距 (默认: 2.5cm)
    --margin-left SIZE      左边距 (默认: 2.5cm)
    --margin-right SIZE     右边距 (默认: 2.5cm)
    --fontsize SIZE         字体大小 (默认: 12pt)
    --papersize SIZE        纸张大小 (a4|letter|a5)
    
    HTML 选项:
    --html-standalone       生成独立 HTML (包含 CSS)
    --html-css THEME        CSS 主题 (github|simple|elegant)
    --html-template FILE    自定义 HTML 模板
    
    PPT 选项:
    --slide-level N         幻灯片级别 (默认: 2)
    --incremental           渐进式列表
    
    -h, --help              显示此帮助信息

示例:
    # 批量转换为 DOCX
    $0 *.md
    
    # 批量转换为 PDF 带目录
    $0 -f pdf --toc file1.md file2.md
EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --input-format)
                INPUT_FORMAT="$2"
                shift 2
                ;;
            --no-template)
                USE_TEMPLATE=false
                shift
                ;;
            --toc)
                TOC_ENABLED=true
                shift
                ;;
            --toc-depth)
                TOC_DEPTH="$2"
                shift 2
                ;;
            --number-sections)
                NUMBER_SECTIONS=true
                shift
                ;;
            --pdf-engine)
                PDF_ENGINE="$2"
                shift 2
                ;;
            --margin-top)
                PDF_MARGIN_TOP="$2"
                shift 2
                ;;
            --margin-bottom)
                PDF_MARGIN_BOTTOM="$2"
                shift 2
                ;;
            --margin-left)
                PDF_MARGIN_LEFT="$2"
                shift 2
                ;;
            --margin-right)
                PDF_MARGIN_RIGHT="$2"
                shift 2
                ;;
            --fontsize)
                PDF_FONTSIZE="$2"
                shift 2
                ;;
            --papersize)
                PDF_PAPERSIZE="$2"
                shift 2
                ;;
            --html-standalone)
                HTML_SELF_CONTAINED=true
                shift
                ;;
            --docx-template)
                DOCX_TEMPLATE="$2"
                shift 2
                ;;
            --html-css)
                HTML_CSS_THEME="$2"
                shift 2
                ;;
            --html-template)
                HTML_TEMPLATE="$2"
                shift 2
                ;;
            --slide-level)
                PPT_SLIDE_LEVEL="$2"
                shift 2
                ;;
            --incremental)
                PPT_INCREMENTAL=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
            *)
                INPUT_FILES+=("$1")
                shift
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    if ! command -v pandoc &> /dev/null; then
        echo -e "${RED}错误: 未找到 pandoc${NC}"
        echo "请运行: ./install.sh"
        exit 1
    fi
    
    if [[ "$OUTPUT_FORMAT" == "pdf" ]] && ! command -v "$PDF_ENGINE" &> /dev/null; then
        echo -e "${YELLOW}警告: 未找到 $PDF_ENGINE${NC}"
        echo "PDF 转换需要 LaTeX 引擎"
        echo "macOS: brew install --cask mactex-no-gui"
        echo "Linux: sudo apt-get install texlive-xetex"
    fi
}

# 构建 Pandoc 命令
build_pandoc_command() {
    local input_file="$1"
    local output_file="$2"
    local input_format="$3"
    local cmd="pandoc \"$input_file\""
    
    # 基本选项
    if [ -n "$input_format" ]; then
        cmd="$cmd -f $input_format"
    else
        cmd="$cmd -f markdown"
    fi
    
    cmd="$cmd -t $OUTPUT_FORMAT"
    
    # 仅在 Markdown 输入时使用 Lua 过滤器
    if [ "$input_format" == "markdown" ] || [ -z "$input_format" ]; then
        cmd="$cmd --lua-filter=\"$FILTER_DIR/mermaid.lua\""
    fi
    
    # 目录
    if [ "$TOC_ENABLED" = true ]; then
        cmd="$cmd --toc --toc-depth=$TOC_DEPTH"
    fi
    
    # 章节编号
    if [ "$NUMBER_SECTIONS" = true ]; then
        cmd="$cmd --number-sections"
    fi
    
    # 格式特定选项
    case $OUTPUT_FORMAT in
        markdown)
            # Markdown 输出：保持简洁
            cmd="$cmd --standalone"
            # 可选：指定 Markdown 变体（gfm=GitHub Flavored Markdown）
            cmd="$cmd --to=gfm"
            ;;
        docx)
            cmd="$cmd --mathml"
            if [ "$USE_TEMPLATE" = true ]; then
                # 使用指定的模板，默认为 reference
                local template_name="${DOCX_TEMPLATE:-reference}"
                local template_file="$TEMPLATE_DIR/${template_name}.docx"
                
                if [ -f "$template_file" ]; then
                    cmd="$cmd --reference-doc=\"$template_file\""
                else
                    echo "警告: 模板文件不存在: $template_file" >&2
                    echo "使用默认模板" >&2
                    if [ -f "$TEMPLATE_DIR/reference.docx" ]; then
                        cmd="$cmd --reference-doc=\"$TEMPLATE_DIR/reference.docx\""
                    fi
                fi
            fi
            ;;
        pdf)
            # 根据 PDF 引擎类型使用不同的选项
            case $PDF_ENGINE in
                xelatex|pdflatex|lualatex)
                    # LaTeX 引擎
                    cmd="$cmd --pdf-engine=$PDF_ENGINE"
                    cmd="$cmd -V geometry:top=$PDF_MARGIN_TOP"
                    cmd="$cmd -V geometry:bottom=$PDF_MARGIN_BOTTOM"
                    cmd="$cmd -V geometry:left=$PDF_MARGIN_LEFT"
                    cmd="$cmd -V geometry:right=$PDF_MARGIN_RIGHT"
                    cmd="$cmd -V fontsize=$PDF_FONTSIZE"
                    cmd="$cmd -V papersize=$PDF_PAPERSIZE"
                    
                    # XeLaTeX 和 LuaLaTeX 支持中文字体
                    if [ "$PDF_ENGINE" = "xelatex" ] || [ "$PDF_ENGINE" = "lualatex" ]; then
                        cmd="$cmd -V CJKmainfont='PingFang SC'"
                        cmd="$cmd -V mainfont='Times New Roman'"
                    fi
                    ;;
                html5)
                    # Chromium 引擎 (Pandoc 3.x 原生支持)
                    cmd="$cmd --pdf-engine=html5"
                    # html5 引擎通过 CSS 控制样式
                    cmd="$cmd --css=<(echo 'body { margin: $PDF_MARGIN_TOP $PDF_MARGIN_RIGHT $PDF_MARGIN_BOTTOM $PDF_MARGIN_LEFT; }')"
                    ;;
                weasyprint)
                    # WeasyPrint 引擎
                    cmd="$cmd --pdf-engine=weasyprint"
                    # WeasyPrint 通过 CSS 控制样式
                    ;;
                *)
                    # 默认使用 xelatex
                    cmd="$cmd --pdf-engine=xelatex"
                    cmd="$cmd -V geometry:top=$PDF_MARGIN_TOP"
                    cmd="$cmd -V geometry:bottom=$PDF_MARGIN_BOTTOM"
                    cmd="$cmd -V geometry:left=$PDF_MARGIN_LEFT"
                    cmd="$cmd -V geometry:right=$PDF_MARGIN_RIGHT"
                    cmd="$cmd -V fontsize=$PDF_FONTSIZE"
                    cmd="$cmd -V papersize=$PDF_PAPERSIZE"
                    cmd="$cmd -V CJKmainfont='PingFang SC'"
                    cmd="$cmd -V mainfont='Times New Roman'"
                    ;;
            esac
            ;;
        html)
            if [ "$HTML_SELF_CONTAINED" = true ]; then
                cmd="$cmd --embed-resources --standalone"
            fi
            if [ -f "$PROJECT_DIR/templates/html-$HTML_CSS_THEME.css" ]; then
                cmd="$cmd --css=\"$PROJECT_DIR/templates/html-$HTML_CSS_THEME.css\""
            fi
            if [ -n "$HTML_TEMPLATE" ] && [ -f "$HTML_TEMPLATE" ]; then
                cmd="$cmd --template=\"$HTML_TEMPLATE\""
            fi
            cmd="$cmd --mathjax"
            ;;
        pptx)
            # 优化幻灯片级别：使用 2 级标题作为新幻灯片，避免内容过多
            cmd="$cmd --slide-level=2"
            
            # 添加变量设置，优化字体和间距
            cmd="$cmd -V fontsize=16pt"
            cmd="$cmd -V monofont='Menlo'"
            
            # 添加 PPT 优化过滤器
            if [ -f "$FILTER_DIR/ppt-optimize.lua" ]; then
                cmd="$cmd --lua-filter=\"$FILTER_DIR/ppt-optimize.lua\""
            fi
            
            if [ "$PPT_INCREMENTAL" = true ]; then
                cmd="$cmd --incremental"
            fi
            if [ "$USE_TEMPLATE" = true ] && [ -f "$TEMPLATE_DIR/reference.pptx" ]; then
                cmd="$cmd --reference-doc=\"$TEMPLATE_DIR/reference.pptx\""
            fi
            ;;
        txt)
            # 纯文本输出：简单格式
            cmd="$cmd --to=plain"
            ;;
        epub)
            cmd="$cmd --mathml"
            if [ "$USE_TEMPLATE" = true ] && [ -f "$TEMPLATE_DIR/epub.css" ]; then
                cmd="$cmd --css=\"$TEMPLATE_DIR/epub.css\""
            fi
            ;;
        xlsx)
            # Excel 转换使用专用脚本
            # 不使用 Pandoc,直接返回空命令
            echo ""
            return 0
            ;;
    esac
    
    # 输出文件
    cmd="$cmd -o \"$output_file\""
    
    echo "$cmd"
}

# 主函数
main() {
    parse_args "$@"
    
    # 检查输入文件
    if [ ${#INPUT_FILES[@]} -eq 0 ]; then
        echo -e "${RED}错误: 未指定输入文件${NC}"
        show_help
        exit 1
    fi
    
    # 检查依赖
    check_dependencies
    
    echo -e "${BLUE}开始批量转换 ${#INPUT_FILES[@]} 个文件...${NC}"
    echo -e "  格式: $OUTPUT_FORMAT"
    echo ""
    
    local success_count=0
    local fail_count=0
    
    for input_file in "${INPUT_FILES[@]}"; do
        if [ ! -f "$input_file" ]; then
            echo -e "${RED}错误: 文件不存在: $input_file${NC}"
            ((fail_count++))
            continue
        fi
        
        # 生成输出文件名
        local base_name="${input_file%.*}"
        local ext="${OUTPUT_FORMAT}"
        if [ "$ext" = "markdown" ]; then
            ext="md"
        fi
        local output_file="${base_name}.${ext}"
        
        # 自动检测输入格式
        local input_format="$INPUT_FORMAT"
        if [ "$input_format" = "markdown" ] && command -v file &> /dev/null; then
            local file_type=$(file -b "$input_file")
            if [[ "$file_type" == *"Microsoft Word"* ]] || [[ "$file_type" == *"Word 2007+"* ]]; then
                input_format="docx"
                echo -e "${YELLOW}提示: 检测到输入文件为 Word 文档${NC}"
            fi
        fi
        
        echo -e "正在转换: $input_file -> $output_file"
        
        # Excel 转换使用专用脚本
        if [ "$OUTPUT_FORMAT" = "xlsx" ]; then
            if "$SCRIPT_DIR/md2xlsx.sh" "$input_file" "$output_file" > /dev/null 2>&1; then
                local file_size=$(du -h "$output_file" | cut -f1)
                echo -e "${GREEN}✓ 成功${NC} ($file_size)"
                ((success_count++))
            else
                echo -e "${RED}✗ 失败${NC}"
                ((fail_count++))
            fi
        else
            # 构建并执行 Pandoc 命令
            local pandoc_cmd=$(build_pandoc_command "$input_file" "$output_file" "$input_format")
            
            if eval "$pandoc_cmd"; then
                local file_size=$(du -h "$output_file" | cut -f1)
                echo -e "${GREEN}✓ 成功${NC} ($file_size)"
                # 打开预览

                ((success_count++))
            else
                echo -e "${RED}✗ 失败${NC}"
                ((fail_count++))
            fi
        fi
        echo ""
    done
    
    echo "----------------------------------------"
    echo -e "转换完成: ${GREEN}$success_count 成功${NC}, ${RED}$fail_count 失败${NC}"
    
    if [ $fail_count -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# 运行主函数
main "$@"

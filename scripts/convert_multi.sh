#!/bin/bash

# Markdown 多格式转换脚本
# 支持: DOCX, PDF, HTML, PPTX, EPUB

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

# 显示帮助信息
show_help() {
    cat << EOF
Markdown 多格式转换工具

用法:
    $0 [选项] <输入文件> [输出文件]

支持的格式:
    docx    - Microsoft Word 文档 (默认)
    pdf     - PDF 文档
    html    - HTML 网页
    pptx    - PowerPoint 演示文稿
    epub    - 电子书

选项:
    -f, --format FORMAT     输出格式 (docx|pdf|html|pptx|epub)
    -o, --output FILE       输出文件路径
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
    # 转换为 DOCX
    $0 document.md
    
    # 转换为 PDF 带目录
    $0 -f pdf --toc document.md output.pdf
    
    # 转换为 HTML
    $0 -f html --html-css github document.md
    
    # 转换为 PPT
    $0 -f pptx document.md presentation.pptx

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
            -o|--output)
                OUTPUT_FILE="$2"
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
                if [ -z "$INPUT_FILE" ]; then
                    INPUT_FILE="$1"
                elif [ -z "$OUTPUT_FILE" ]; then
                    OUTPUT_FILE="$1"
                fi
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
    local cmd="pandoc \"$INPUT_FILE\""
    
    # 基本选项
    cmd="$cmd -f markdown"
    cmd="$cmd -t $OUTPUT_FORMAT"
    cmd="$cmd --lua-filter=\"$FILTER_DIR/mermaid.lua\""
    
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
        epub)
            cmd="$cmd --mathml"
            if [ "$USE_TEMPLATE" = true ] && [ -f "$TEMPLATE_DIR/epub.css" ]; then
                cmd="$cmd --css=\"$TEMPLATE_DIR/epub.css\""
            fi
            ;;
    esac
    
    # 输出文件
    cmd="$cmd -o \"$OUTPUT_FILE\""
    
    echo "$cmd"
}

# 主函数
main() {
    parse_args "$@"
    
    # 检查输入文件
    if [ -z "$INPUT_FILE" ]; then
        echo -e "${RED}错误: 未指定输入文件${NC}"
        show_help
        exit 1
    fi
    
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}错误: 文件不存在: $INPUT_FILE${NC}"
        exit 1
    fi
    
    # 生成输出文件名
    if [ -z "$OUTPUT_FILE" ]; then
        local base_name="${INPUT_FILE%.*}"
        OUTPUT_FILE="${base_name}.${OUTPUT_FORMAT}"
    fi
    
    # 检查依赖
    check_dependencies
    
    # 显示转换信息
    echo -e "${BLUE}开始转换...${NC}"
    echo -e "  输入: $INPUT_FILE"
    echo -e "  输出: $OUTPUT_FILE"
    echo -e "  格式: $OUTPUT_FORMAT"
    echo ""
    
    # 构建并执行命令
    local pandoc_cmd=$(build_pandoc_command)
    
    if eval "$pandoc_cmd"; then
        local file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo ""
        echo -e "${GREEN}✓ 转换成功!${NC}"
        echo -e "  输出文件: $OUTPUT_FILE"
        echo -e "  文件大小: $file_size"
    else
        echo -e "${RED}✗ 转换失败${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"

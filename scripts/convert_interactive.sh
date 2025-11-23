#!/usr/bin/env bash

# Markdown 交互式转换工具
# 提供友好的菜单界面,无需记忆复杂参数

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 配置文件路径
CONFIG_FILE="$HOME/.mdconv.yaml"
LAST_CONFIG_FILE="$HOME/.mdconv_last.yaml"

# 默认配置
INPUT_FILE=""
OUTPUT_FORMAT="docx"
OUTPUT_FILE=""
TOC_ENABLED="n"
NUMBER_SECTIONS="n"
PDF_PRESET="standard"
HTML_THEME="github"
PPT_STYLE="business"
DOCX_TEMPLATE="reference"

# 获取预设配置 (兼容 bash 3.2)
get_preset() {
    local preset="$1"
    case $preset in
        academic)
            echo "format=pdf toc=y number_sections=y pdf_preset=academic"
            ;;
        report)
            echo "format=pdf toc=y number_sections=y pdf_preset=technical"
            ;;
        book)
            echo "format=pdf toc=y number_sections=y pdf_preset=book"
            ;;
        resume)
            echo "format=docx toc=n number_sections=n"
            ;;
        presentation)
            echo "format=pptx"
            ;;
        article)
            echo "format=html html_theme=github"
            ;;
        web)
            echo "format=html html_theme=github toc=y"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# 显示标题
show_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║           🎯 Markdown 多格式转换工具                      ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# 读取用户输入
read_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        echo -ne "${CYAN}${prompt} [${default}]: ${NC}"
    else
        echo -ne "${CYAN}${prompt}: ${NC}"
    fi
    
    read -r input
    if [ -z "$input" ] && [ -n "$default" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

# 加载上次配置
load_last_config() {
    if [ -f "$LAST_CONFIG_FILE" ]; then
        source "$LAST_CONFIG_FILE" 2>/dev/null || true
    fi
}

# 保存当前配置
save_last_config() {
    cat > "$LAST_CONFIG_FILE" << EOF
OUTPUT_FORMAT="$OUTPUT_FORMAT"
TOC_ENABLED="$TOC_ENABLED"
NUMBER_SECTIONS="$NUMBER_SECTIONS"
PDF_PRESET="$PDF_PRESET"
HTML_THEME="$HTML_THEME"
PPT_STYLE="$PPT_STYLE"
EOF
}

# 加载配置文件
load_config_file() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓ 找到配置文件: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}是否使用配置文件? (Y/n): ${NC}"
        read -r use_config
        if [ "$use_config" != "n" ] && [ "$use_config" != "N" ]; then
            # 简单的 YAML 解析
            while IFS=': ' read -r key value; do
                case $key in
                    format) OUTPUT_FORMAT="$value" ;;
                    toc) TOC_ENABLED="$value" ;;
                    number_sections) NUMBER_SECTIONS="$value" ;;
                    pdf_preset) PDF_PRESET="$value" ;;
                    html_theme) HTML_THEME="$value" ;;
                esac
            done < "$CONFIG_FILE"
            return 0
        fi
    fi
    return 1
}

# 应用预设
apply_preset() {
    local preset="$1"
    local config=$(get_preset "$preset")
    
    if [ $? -eq 0 ]; then
        for item in $config; do
            local key="${item%%=*}"
            local value="${item#*=}"
            case $key in
                format) OUTPUT_FORMAT="$value" ;;
                toc) TOC_ENABLED="$value" ;;
                number_sections) NUMBER_SECTIONS="$value" ;;
                pdf_preset) PDF_PRESET="$value" ;;
                html_theme) HTML_THEME="$value" ;;
            esac
        done
        return 0
    fi
    return 1
}

# 步骤1: 选择输出格式
step_select_format() {
    show_header
    echo -e "${BOLD}步骤 1/3: 选择输出格式${NC}"
    echo ""
    
    # 检测输入格式
    local detected_format=$(detect_input_format "$INPUT_FILE")
    echo -e "  检测到输入格式: ${CYAN}$(echo "$detected_format" | tr '[:lower:]' '[:upper:]')${NC}"
    echo ""
    
    # 构建可用格式列表 (过滤掉输入格式,避免自己转自己)
    local format_list=()
    local format_names=()
    local format_index=1
    
    # 定义所有格式
    if [ "$detected_format" != "markdown" ]; then
        format_list+=("markdown")
        format_names+=("Markdown")
        echo -e "  ${GREEN}[$format_index]${NC} Markdown  - Markdown 文档"
        ((format_index++))
    fi
    
    if [ "$detected_format" != "docx" ]; then
        format_list+=("docx")
        format_names+=("Word 文档")
        echo -e "  ${GREEN}[$format_index]${NC} DOCX      - Microsoft Word 文档"
        ((format_index++))
    fi
    
    if [ "$detected_format" != "pdf" ]; then
        format_list+=("pdf")
        format_names+=("PDF 文档")
        echo -e "  ${GREEN}[$format_index]${NC} PDF       - PDF 文档 (需要 PDF 引擎)"
        ((format_index++))
    fi
    
    if [ "$detected_format" != "html" ]; then
        format_list+=("html")
        format_names+=("网页")
        echo -e "  ${GREEN}[$format_index]${NC} HTML      - 网页文件"
        ((format_index++))
    fi
    
    if [ "$detected_format" != "plain" ] && [ "$detected_format" != "txt" ]; then
        format_list+=("txt")
        format_names+=("纯文本")
        echo -e "  ${GREEN}[$format_index]${NC} TXT       - 纯文本"
        ((format_index++))
    fi
    
    if [ "$detected_format" != "pptx" ]; then
        format_list+=("pptx")
        format_names+=("演示文稿")
        echo -e "  ${GREEN}[$format_index]${NC} PPTX      - PowerPoint 演示文稿"
        ((format_index++))
    fi
    
    if [ "$detected_format" != "epub" ]; then
        format_list+=("epub")
        format_names+=("电子书")
        echo -e "  ${GREEN}[$format_index]${NC} EPUB      - 电子书"
        ((format_index++))
    fi
    
    echo ""
    
    # 查找当前输出格式的索引
    local default_choice="1"
    for i in "${!format_list[@]}"; do
        if [ "${format_list[$i]}" = "$OUTPUT_FORMAT" ]; then
            default_choice=$((i + 1))
            break
        fi
    done
    
    # 如果当前输出格式与输入格式相同,智能选择默认格式
    if [ "$OUTPUT_FORMAT" = "$detected_format" ]; then
        case $detected_format in
            markdown)
                # Markdown → DOCX
                for i in "${!format_list[@]}"; do
                    if [ "${format_list[$i]}" = "docx" ]; then
                        default_choice=$((i + 1))
                        OUTPUT_FORMAT="docx"
                        break
                    fi
                done
                ;;
            docx)
                # DOCX → Markdown
                for i in "${!format_list[@]}"; do
                    if [ "${format_list[$i]}" = "markdown" ]; then
                        default_choice=$((i + 1))
                        OUTPUT_FORMAT="markdown"
                        break
                    fi
                done
                ;;
            html)
                # HTML → DOCX
                for i in "${!format_list[@]}"; do
                    if [ "${format_list[$i]}" = "docx" ]; then
                        default_choice=$((i + 1))
                        OUTPUT_FORMAT="docx"
                        break
                    fi
                done
                ;;
            *)
                # 其他 → Markdown
                for i in "${!format_list[@]}"; do
                    if [ "${format_list[$i]}" = "markdown" ]; then
                        default_choice=$((i + 1))
                        OUTPUT_FORMAT="markdown"
                        break
                    fi
                done
                ;;
        esac
    fi
    
    local max_choice=${#format_list[@]}
    read_input "请选择 (1-$max_choice)" "$default_choice" choice
    
    # 验证输入并设置输出格式
    if [ "$choice" -ge 1 ] && [ "$choice" -le "$max_choice" ]; then
        OUTPUT_FORMAT="${format_list[$((choice - 1))]}"
    else
        OUTPUT_FORMAT="${format_list[0]}"
    fi
}

# 步骤2: 文档选项
step_document_options() {
    show_header
    echo -e "${BOLD}步骤 2/3: 文档选项${NC}"
    echo ""
    # 兼容 bash 3.2 的大写转换
    local format_upper=$(echo "$OUTPUT_FORMAT" | tr '[:lower:]' '[:upper:]')
    echo -e "输出格式: ${GREEN}${format_upper}${NC}"
    echo ""
    
    read_input "生成目录? (Y/n)" "$TOC_ENABLED" TOC_ENABLED
    TOC_ENABLED=$(echo "$TOC_ENABLED" | tr '[:upper:]' '[:lower:]')  # 转小写
    
    read_input "章节编号? (Y/n)" "$NUMBER_SECTIONS" NUMBER_SECTIONS
    NUMBER_SECTIONS=$(echo "$NUMBER_SECTIONS" | tr '[:upper:]' '[:lower:]')
}

# 步骤3: 格式特定配置
step_format_specific() {
    show_header
    local format_upper=$(echo "$OUTPUT_FORMAT" | tr '[:lower:]' '[:upper:]')
    echo -e "${BOLD}步骤 3/3: ${format_upper} 特定配置${NC}"
    echo ""
    
    case $OUTPUT_FORMAT in
        pdf)
            echo -e "选择 PDF 预设:"
            echo -e "  ${GREEN}[1]${NC} 学术论文 (A4, 标准边距, 12pt, 双面)"
            echo -e "  ${GREEN}[2]${NC} 技术文档 (A4, 标准边距, 11pt)"
            echo -e "  ${GREEN}[3]${NC} 书籍 (A5, 大边距, 10pt)"
            echo -e "  ${GREEN}[4]${NC} 标准文档 (A4, 标准边距, 12pt)"
            echo ""
            
            local default_choice="4"
            case $PDF_PRESET in
                academic) default_choice="1" ;;
                technical) default_choice="2" ;;
                book) default_choice="3" ;;
                standard) default_choice="4" ;;
            esac
            
            read_input "请选择 (1-4)" "$default_choice" choice
            
            case $choice in
                1) PDF_PRESET="academic" ;;
                2) PDF_PRESET="technical" ;;
                3) PDF_PRESET="book" ;;
                *) PDF_PRESET="standard" ;;
            esac
            ;;
        html)
            echo -e "选择 HTML 主题:"
            echo -e "  ${GREEN}[1]${NC} GitHub 风格 (推荐)"
            echo -e "  ${GREEN}[2]${NC} 简约风格"
            echo -e "  ${GREEN}[3]${NC} 优雅风格"
            echo ""
            
            local default_choice="1"
            case $HTML_THEME in
                github) default_choice="1" ;;
                simple) default_choice="2" ;;
                elegant) default_choice="3" ;;
            esac
            
            read_input "请选择 (1-3)" "$default_choice" choice
            
            case $choice in
                1) HTML_THEME="github" ;;
                2) HTML_THEME="simple" ;;
                3) HTML_THEME="elegant" ;;
                *) HTML_THEME="github" ;;
            esac
            ;;
        docx)
            echo -e "选择 Word 模板:"
            echo -e "  ${GREEN}[1]${NC} 默认模板 (通用)"
            echo -e "  ${GREEN}[2]${NC} 学术论文 (宋体，严谨，标题层级清晰)"
            echo -e "  ${GREEN}[3]${NC} 商务报告 (微软雅黑，现代)"
            echo -e "  ${GREEN}[4]${NC} 技术文档 (等线，清晰)"
            echo -e "  ${GREEN}[5]${NC} 简洁现代 (苹方，简约)"
            echo ""
            
            local default_choice="1"
            case $DOCX_TEMPLATE in
                reference) default_choice="1" ;;
                academic) default_choice="2" ;;
                business) default_choice="3" ;;
                technical) default_choice="4" ;;
                modern) default_choice="5" ;;
            esac
            
            read_input "请选择 (1-5)" "$default_choice" choice
            
            case $choice in
                1) DOCX_TEMPLATE="reference" ;;
                2) DOCX_TEMPLATE="academic" ;;
                3) DOCX_TEMPLATE="business" ;;
                4) DOCX_TEMPLATE="technical" ;;
                5) DOCX_TEMPLATE="modern" ;;
                *) DOCX_TEMPLATE="reference" ;;
            esac
            ;;
        pptx)
            echo -e "选择 PPT 风格:"
            echo -e "  ${GREEN}[1]${NC} 商务风格"
            echo -e "  ${GREEN}[2]${NC} 技术风格"
            echo -e "  ${GREEN}[3]${NC} 简约风格"
            echo ""
            
            read_input "请选择 (1-3)" "1" choice
            
            case $choice in
                1) PPT_STYLE="business" ;;
                2) PPT_STYLE="technical" ;;
                3) PPT_STYLE="simple" ;;
                *) PPT_STYLE="business" ;;
            esac
            ;;
        *)
            echo -e "${GREEN}使用默认配置${NC}"
            sleep 1
            ;;
    esac
}

# 显示配置摘要
show_summary() {
    show_header
    echo -e "${BOLD}配置摘要${NC}"
    echo ""
    echo -e "  输入文件:   ${CYAN}$INPUT_FILE${NC}"
    echo -e "  输出格式:   ${GREEN}$(echo "$OUTPUT_FORMAT" | tr '[:lower:]' '[:upper:]')${NC}"
    echo -e "  生成目录:   ${YELLOW}$TOC_ENABLED${NC}"
    echo -e "  章节编号:   ${YELLOW}$NUMBER_SECTIONS${NC}"
    
    case $OUTPUT_FORMAT in
        docx)
            echo -e "  Word 模板:  ${YELLOW}$DOCX_TEMPLATE${NC}"
            ;;
        pdf)
            echo -e "  PDF 预设:   ${YELLOW}$PDF_PRESET${NC}"
            ;;
        html)
            echo -e "  HTML 主题:  ${YELLOW}$HTML_THEME${NC}"
            ;;
        pptx)
            echo -e "  PPT 风格:   ${YELLOW}$PPT_STYLE${NC}"
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}按 Enter 开始转换,或输入 'q' 取消: ${NC}"
    read -r confirm
    
    if [ "$confirm" = "q" ] || [ "$confirm" = "Q" ]; then
        echo -e "${RED}已取消${NC}"
        exit 0
    fi
}

# 构建转换命令
build_convert_command() {
    local cmd="$SCRIPT_DIR/convert_multi.sh"
    
    cmd="$cmd -f $OUTPUT_FORMAT"
    
    if [ "$TOC_ENABLED" = "y" ] || [ "$TOC_ENABLED" = "Y" ]; then
        cmd="$cmd --toc"
    fi
    
    if [ "$NUMBER_SECTIONS" = "y" ] || [ "$NUMBER_SECTIONS" = "Y" ]; then
        cmd="$cmd --number-sections"
    fi
    
    case $OUTPUT_FORMAT in
        docx)
            # 添加 Word 模板参数
            cmd="$cmd --docx-template $DOCX_TEMPLATE"
            ;;
        pdf)
            # 检测可用的 PDF 引擎
            local pdf_engine
            if [ -f "$SCRIPT_DIR/detect_pdf_engine.sh" ]; then
                pdf_engine=$("$SCRIPT_DIR/detect_pdf_engine.sh")
                if [ $? -eq 0 ] && [ -n "$pdf_engine" ] && [ "$pdf_engine" != "none" ]; then
                    cmd="$cmd --pdf-engine $pdf_engine"
                else
                    echo -e "${RED}错误: 未找到可用的 PDF 引擎${NC}" >&2
                    echo -e "${YELLOW}请运行 ./install.sh 安装 PDF 引擎${NC}" >&2
                    return 1
                fi
            fi
            
            case $PDF_PRESET in
                academic)
                    cmd="$cmd --margin-top 2.5cm --margin-bottom 2.5cm"
                    cmd="$cmd --margin-left 3cm --margin-right 3cm"
                    cmd="$cmd --fontsize 12pt --papersize a4"
                    ;;
                technical)
                    cmd="$cmd --margin-top 2cm --margin-bottom 2cm"
                    cmd="$cmd --margin-left 2.5cm --margin-right 2.5cm"
                    cmd="$cmd --fontsize 11pt --papersize a4"
                    ;;
                book)
                    cmd="$cmd --margin-top 3cm --margin-bottom 3cm"
                    cmd="$cmd --margin-left 3.5cm --margin-right 2.5cm"
                    cmd="$cmd --fontsize 10pt --papersize a5"
                    ;;
                standard)
                    cmd="$cmd --margin-top 2.5cm --margin-bottom 2.5cm"
                    cmd="$cmd --margin-left 2.5cm --margin-right 2.5cm"
                    cmd="$cmd --fontsize 12pt --papersize a4"
                    ;;
            esac
            ;;
        html)
            cmd="$cmd --html-css $HTML_THEME"
            ;;
    esac
    
    cmd="$cmd \"$INPUT_FILE\""
    
    if [ -n "$OUTPUT_FILE" ]; then
        cmd="$cmd \"$OUTPUT_FILE\""
    fi
    
    echo "$cmd"
}

# 执行转换
execute_conversion() {
    echo ""
    echo -e "${BLUE}开始转换...${NC}"
    echo ""
    
    local cmd=$(build_convert_command)
    
    if eval "$cmd"; then
        echo ""
        echo -e "${GREEN}${BOLD}✓ 转换成功!${NC}"
        
        # 保存配置
        save_last_config
        
        # 询问是否打开文件
        echo ""
        echo -e "${YELLOW}是否打开输出文件? (Y/n): ${NC}"
        read -r open_file
        if [ "$open_file" != "n" ] && [ "$open_file" != "N" ]; then
            local output="${OUTPUT_FILE:-${INPUT_FILE%.*}.$OUTPUT_FORMAT}"
            if [ -f "$output" ]; then
                open "$output" 2>/dev/null || xdg-open "$output" 2>/dev/null || true
            fi
        fi
    else
        echo ""
        echo -e "${RED}${BOLD}✗ 转换失败${NC}"
        exit 1
    fi
}

# 显示帮助
show_help() {
    cat << EOF
Markdown 交互式转换工具

用法:
    $0 [选项] <输入文件>

选项:
    --preset NAME       使用预设配置
                        academic    - 学术论文
                        report      - 技术报告
                        book        - 书籍
                        resume      - 简历
                        presentation- 演示文稿
                        article     - 文章
                        web         - 网页
    
    --config FILE       使用配置文件
    --no-interactive    非交互模式 (使用默认值)
    -h, --help          显示帮助信息

示例:
    # 交互式转换
    $0 document.md
    
    # 使用预设
    $0 --preset academic paper.md
    
    # 使用配置文件
    $0 --config .mdconv.yaml document.md

EOF
}

# 主函数
main() {
    local use_preset=""
    local use_config_file=""
    local interactive=true
    local input_files=()
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --preset)
                use_preset="$2"
                shift 2
                ;;
            --config)
                use_config_file="$2"
                shift 2
                ;;
            --no-interactive)
                interactive=false
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
                input_files+=("$1")
                shift
                ;;
        esac
    done
    
    # 检查输入文件
    if [ ${#input_files[@]} -eq 0 ]; then
        show_help
        exit 1
    fi
    
    # 如果有多个文件，需要先交互配置再批量转换
    if [ ${#input_files[@]} -gt 1 ]; then
        echo -e "${YELLOW}检测到 ${#input_files[@]} 个文件，将使用相同配置批量转换${NC}"
        echo ""
        
        # 使用第一个文件进行格式检测
        INPUT_FILE="${input_files[0]}"
        
        # 加载配置
        if [ -n "$use_preset" ]; then
            if apply_preset "$use_preset"; then
                echo -e "${GREEN}✓ 使用预设: $use_preset${NC}"
                interactive=false
            else
                echo -e "${RED}错误: 未知预设: $use_preset${NC}"
                exit 1
            fi
        elif [ -n "$use_config_file" ]; then
            CONFIG_FILE="$use_config_file"
            load_config_file
            interactive=false
        else
            load_last_config
        fi
        
        # 交互式流程（如果需要）
        if [ "$interactive" = true ]; then
            step_select_format
            step_document_options
            step_format_specific
            
            # 显示批量转换摘要
            show_header
            echo -e "${BOLD}批量转换配置摘要${NC}"
            echo ""
            echo -e "  文件数量:   ${CYAN}${#input_files[@]}${NC}"
            echo -e "  输出格式:   ${GREEN}$(echo "$OUTPUT_FORMAT" | tr '[:lower:]' '[:upper:]')${NC}"
            echo -e "  生成目录:   ${YELLOW}$TOC_ENABLED${NC}"
            echo -e "  章节编号:   ${YELLOW}$NUMBER_SECTIONS${NC}"
            
            case $OUTPUT_FORMAT in
                docx)
                    echo -e "  Word 模板:  ${YELLOW}$DOCX_TEMPLATE${NC}"
                    ;;
                pdf)
                    echo -e "  PDF 预设:   ${YELLOW}$PDF_PRESET${NC}"
                    ;;
                html)
                    echo -e "  HTML 主题:  ${YELLOW}$HTML_THEME${NC}"
                    ;;
                pptx)
                    echo -e "  PPT 风格:   ${YELLOW}$PPT_STYLE${NC}"
                    ;;
            esac
            
            echo ""
            echo -e "${YELLOW}按 Enter 开始批量转换,或输入 'q' 取消: ${NC}"
            read -r confirm
            
            if [ "$confirm" = "q" ] || [ "$confirm" = "Q" ]; then
                echo -e "${RED}已取消${NC}"
                exit 0
            fi
        fi
        
        # 构建批量转换命令（使用数组避免参数分割问题）
        local batch_args=()
        
        # 检测输入格式
        if [ "$INPUT_FORMAT" = "auto" ]; then
            INPUT_FORMAT=$(detect_input_format "$INPUT_FILE")
        fi
        
        # 如果输入格式不是 markdown,添加 --input-format 参数
        if [ "$INPUT_FORMAT" != "markdown" ]; then
            batch_args+=("--input-format" "$INPUT_FORMAT")
        fi
        
        # 添加格式参数
        batch_args+=("-f" "$OUTPUT_FORMAT")
        
        # 添加其他选项
        if [ "$TOC_ENABLED" = "y" ] || [ "$TOC_ENABLED" = "Y" ]; then
            batch_args+=("--toc")
        fi
        
        if [ "$NUMBER_SECTIONS" = "y" ] || [ "$NUMBER_SECTIONS" = "Y" ]; then
            batch_args+=("--number-sections")
        fi
        
        # 添加格式特定选项
        case $OUTPUT_FORMAT in
            docx)
                batch_args+=("--docx-template" "$DOCX_TEMPLATE")
                ;;
            pptx)
                batch_args+=("--pptx-style" "$PPT_STYLE")
                ;;
            html)
                batch_args+=("--html-css" "$HTML_THEME")
                ;;
            pdf)
                # 检测 PDF 引擎
                local pdf_engine
                if [ -f "$SCRIPT_DIR/detect_pdf_engine.sh" ]; then
                    pdf_engine=$("$SCRIPT_DIR/detect_pdf_engine.sh")
                    if [ $? -eq 0 ] && [ -n "$pdf_engine" ] && [ "$pdf_engine" != "none" ]; then
                        batch_args+=("--pdf-engine" "$pdf_engine")
                    fi
                fi
                
                # 添加 PDF 预设参数
                case $PDF_PRESET in
                    academic)
                        batch_args+=("--margin-top" "2.5cm" "--margin-bottom" "2.5cm")
                        batch_args+=("--margin-left" "3cm" "--margin-right" "3cm")
                        batch_args+=("--fontsize" "12pt" "--papersize" "a4")
                        ;;
                    technical)
                        batch_args+=("--margin-top" "2cm" "--margin-bottom" "2cm")
                        batch_args+=("--margin-left" "2.5cm" "--margin-right" "2.5cm")
                        batch_args+=("--fontsize" "11pt" "--papersize" "a4")
                        ;;
                    book)
                        batch_args+=("--margin-top" "3cm" "--margin-bottom" "3cm")
                        batch_args+=("--margin-left" "3.5cm" "--margin-right" "2.5cm")
                        batch_args+=("--fontsize" "10pt" "--papersize" "a5")
                        ;;
                    standard)
                        batch_args+=("--margin-top" "2.5cm" "--margin-bottom" "2.5cm")
                        batch_args+=("--margin-left" "2.5cm" "--margin-right" "2.5cm")
                        batch_args+=("--fontsize" "12pt" "--papersize" "a4")
                        ;;
                esac
                ;;
        esac
        
        # 添加所有输入文件
        for file in "${input_files[@]}"; do
            batch_args+=("$file")
        done
        
        # 执行批量转换
        echo ""
        "$SCRIPT_DIR/convert_multi.sh" "${batch_args[@]}"
        
        # 保存配置
        save_last_config
        
        exit $?
    fi
    
    # 单文件处理
    INPUT_FILE="${input_files[0]}"
    
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}错误: 文件不存在: $INPUT_FILE${NC}"
        exit 1
    fi
    
    # 加载配置
    if [ -n "$use_preset" ]; then
        if apply_preset "$use_preset"; then
            echo -e "${GREEN}✓ 使用预设: $use_preset${NC}"
            interactive=false
        else
            echo -e "${RED}错误: 未知预设: $use_preset${NC}"
            exit 1
        fi
    elif [ -n "$use_config_file" ]; then
        CONFIG_FILE="$use_config_file"
        load_config_file
        interactive=false
    else
        load_last_config
    fi
    
    # 交互式流程
    if [ "$interactive" = true ]; then
        step_select_format
        step_document_options
        step_format_specific
        show_summary
    fi
    
    # 执行转换
    execute_conversion
}

# 运行主程序
main "$@"

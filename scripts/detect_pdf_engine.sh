#!/usr/bin/env bash

# PDF 引擎检测和选择脚本
# 按优先级自动检测可用的 PDF 引擎

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检测可用的 PDF 引擎
detect_pdf_engine() {
    local preferred_engine="$1"
    
    # 如果指定了首选引擎且可用，直接返回
    if [ -n "$preferred_engine" ]; then
        case $preferred_engine in
            xelatex|pdflatex|lualatex)
                if command_exists "$preferred_engine"; then
                    echo "$preferred_engine"
                    return 0
                fi
                ;;
            wkhtmltopdf)
                if command_exists wkhtmltopdf; then
                    echo "wkhtmltopdf"
                    return 0
                fi
                ;;
            weasyprint)
                if command_exists weasyprint; then
                    echo "weasyprint"
                    return 0
                fi
                ;;
        esac
    fi
    
    # 按优先级检测
    # 1. XeLaTeX (最佳中文支持和排版质量)
    if command_exists xelatex; then
        echo "xelatex"
        return 0
    fi
    
    # 2. LuaLaTeX (次佳 LaTeX 引擎)
    if command_exists lualatex; then
        echo "lualatex"
        return 0
    fi
    
    # 3. PDFLaTeX (基础 LaTeX 引擎)
    if command_exists pdflatex; then
        echo "pdflatex"
        return 0
    fi
    
    # 4. Chromium (Pandoc 3.x 原生支持，现代化渲染)
    if command_exists chromium; then
        echo "html5"
        return 0
    fi
    
    # 5. Chromium (Linux 命名)
    if command_exists chromium-browser; then
        echo "html5"
        return 0
    fi
    
    # 6. Chromium (macOS App)
    if [ -d "/Applications/Chromium.app" ]; then
        echo "html5"
        return 0
    fi
    
    # 7. WeasyPrint (Python-based，轻量级)
    if command_exists weasyprint; then
        echo "weasyprint"
        return 0
    fi
    
    # 没有找到任何引擎
    echo "none"
    return 1
}

# 获取引擎的友好名称
get_engine_name() {
    case $1 in
        xelatex)
            echo "XeLaTeX (推荐, 专业排版)"
            ;;
        lualatex)
            echo "LuaLaTeX (专业排版)"
            ;;
        pdflatex)
            echo "PDFLaTeX (基础排版)"
            ;;
        html5)
            echo "Chromium (现代化渲染)"
            ;;
        weasyprint)
            echo "WeasyPrint (轻量级)"
            ;;
        none)
            echo "未找到"
            ;;
        *)
            echo "$1"
            ;;
    esac
}

# 获取安装建议
get_install_suggestion() {
    local os_type="$1"
    
    echo ""
    echo "建议安装以下 PDF 引擎之一:"
    echo ""
    
    if [[ "$os_type" == "darwin"* ]] || [[ "$os_type" == "macos" ]]; then
        echo "  现代化渲染 (推荐):"
        echo "    brew install --cask chromium"
        echo ""
        echo "  轻量级选项:"
        echo "    pip3 install weasyprint"
        echo ""
        echo "  专业排版 (较大):"
        echo "    brew install --cask mactex-no-gui"
    else
        echo "  现代化渲染 (推荐):"
        echo "    sudo apt-get install chromium-browser"
        echo ""
        echo "  轻量级选项:"
        echo "    pip3 install weasyprint"
        echo ""
        echo "  专业排版 (较大):"
        echo "    sudo apt-get install texlive-xetex texlive-fonts-recommended"
    fi
}

# 主函数
main() {
    local preferred="${1:-}"
    local show_info="${2:-false}"
    
    local engine=$(detect_pdf_engine "$preferred")
    
    if [ "$show_info" = "true" ] || [ "$show_info" = "1" ]; then
        if [ "$engine" = "none" ]; then
            echo "错误: 未找到可用的 PDF 引擎" >&2
            get_install_suggestion "$(uname -s)" >&2
            exit 1
        else
            echo "检测到 PDF 引擎: $(get_engine_name "$engine")" >&2
        fi
    fi
    
    echo "$engine"
    
    if [ "$engine" = "none" ]; then
        exit 1
    fi
}

# 如果直接运行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

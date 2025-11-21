#!/bin/bash

# Markdown to DOCX 自动安装脚本
# 支持 macOS 和 Linux

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}======================================"
echo -e "  Markdown to DOCX 安装程序"
echo -e "======================================${NC}"
echo ""

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        echo -e "${GREEN}✓ 检测到 macOS 系统${NC}"
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux" ]]; then
        OS="linux"
        echo -e "${GREEN}✓ 检测到 Linux 系统${NC}"
        
        # 检测 Linux 发行版
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            LINUX_DISTRO=$ID
            echo -e "${BLUE}  发行版: $NAME${NC}"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo -e "${YELLOW}✓ 检测到 Windows (Git Bash/Cygwin)${NC}"
        echo -e "${YELLOW}  建议使用 PowerShell 运行 install.ps1${NC}"
        OS="windows"
    else
        echo -e "${RED}✗ 不支持的操作系统: $OSTYPE${NC}"
        echo -e "${YELLOW}  支持的系统: macOS, Linux, Windows${NC}"
        exit 1
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 安装 Homebrew (仅 macOS)
install_homebrew() {
    if [[ "$OS" == "macos" ]] && ! command_exists brew; then
        echo -e "${YELLOW}→ 安装 Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 配置 Homebrew 环境变量
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
}

# 安装 Pandoc
install_pandoc() {
    if ! command_exists pandoc; then
        echo -e "${YELLOW}→ 安装 Pandoc...${NC}"
        if [[ "$OS" == "macos" ]]; then
            brew install pandoc
        elif [[ "$OS" == "linux" ]]; then
            if command_exists apt-get; then
                sudo apt-get update
                sudo apt-get install -y pandoc
            elif command_exists yum; then
                sudo yum install -y pandoc
            else
                echo -e "${RED}✗ 无法自动安装 Pandoc,请手动安装${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${GREEN}✓ Pandoc 已安装 ($(pandoc --version | head -n1))${NC}"
    fi
}

# 安装 Node.js
install_nodejs() {
    if ! command_exists node; then
        echo -e "${YELLOW}→ 安装 Node.js...${NC}"
        if [[ "$OS" == "macos" ]]; then
            brew install node
        elif [[ "$OS" == "linux" ]]; then
            # 使用 NodeSource 安装最新 LTS
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
    else
        echo -e "${GREEN}✓ Node.js 已安装 ($(node --version))${NC}"
    fi
}

# 安装 mermaid-cli
install_mermaid_cli() {
    if ! command_exists mmdc; then
        echo -e "${YELLOW}→ 安装 mermaid-cli...${NC}"
        npm install -g @mermaid-js/mermaid-cli
    else
        echo -e "${GREEN}✓ mermaid-cli 已安装 ($(mmdc --version))${NC}"
    fi
}

# 安装 PDF 引擎
install_pdf_engine() {
    echo -e "${BLUE}检查 PDF 转换引擎...${NC}"
    
    # 检查是否已安装 xelatex
    if command_exists xelatex; then
        echo -e "${GREEN}✓ XeLaTeX 已安装 ($(xelatex --version | head -n1))${NC}"
        return 0
    fi
    
    # 检查是否已安装 chromium (Pandoc 3.x 支持)
    if command_exists chromium || command_exists chromium-browser || [ -d "/Applications/Chromium.app" ]; then
        echo -e "${GREEN}✓ Chromium 已安装${NC}"
        return 0
    fi
    
    # 检查是否已安装 weasyprint
    if command_exists weasyprint; then
        echo -e "${GREEN}✓ WeasyPrint 已安装${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}未检测到 PDF 转换引擎${NC}"
    echo ""
    echo -e "${BLUE}可选的 PDF 引擎:${NC}"
    echo -e "  ${GREEN}1)${NC} Chromium (推荐, 约 200MB, 现代化渲染)"
    echo -e "  ${GREEN}2)${NC} WeasyPrint (轻量级, 约 20MB, Python-based)"
    echo -e "  ${GREEN}3)${NC} XeLaTeX (专业排版, 约 4GB, 安装慢)"
    echo -e "  ${GREEN}4)${NC} 跳过 (稍后手动安装)"
    echo ""
    echo -e "${YELLOW}请选择 (1-4) [1]: ${NC}"
    read -r choice
    choice=${choice:-1}
    
    case $choice in
        1)
            echo -e "${YELLOW}→ 安装 Chromium...${NC}"
            if [[ "$OS" == "macos" ]]; then
                brew install --cask chromium
            elif [[ "$OS" == "linux" ]]; then
                if command_exists apt-get; then
                    sudo apt-get update
                    sudo apt-get install -y chromium-browser
                elif command_exists yum; then
                    sudo yum install -y chromium
                else
                    echo -e "${RED}✗ 无法自动安装 Chromium${NC}"
                    echo -e "${YELLOW}  请手动安装 Chromium 浏览器${NC}"
                fi
            fi
            ;;
        2)
            echo -e "${YELLOW}→ 安装 WeasyPrint...${NC}"
            if [[ "$OS" == "macos" ]]; then
                # macOS 使用 Homebrew 安装
                brew install weasyprint
            elif [[ "$OS" == "linux" ]]; then
                # Linux 使用系统包管理器
                if command_exists apt-get; then
                    sudo apt-get update
                    sudo apt-get install -y weasyprint
                elif command_exists yum; then
                    sudo yum install -y weasyprint
                else
                    # 使用 pip 用户安装
                    if command_exists pip3; then
                        pip3 install --user weasyprint
                    elif command_exists pip; then
                        pip install --user weasyprint
                    else
                        echo -e "${RED}✗ 无法安装 WeasyPrint${NC}"
                    fi
                fi
            fi
            ;;
        3)
            echo -e "${YELLOW}→ 安装 XeLaTeX (这可能需要几分钟)...${NC}"
            if [[ "$OS" == "macos" ]]; then
                brew install --cask mactex-no-gui
            elif [[ "$OS" == "linux" ]]; then
                if command_exists apt-get; then
                    sudo apt-get update
                    sudo apt-get install -y texlive-xetex texlive-fonts-recommended texlive-fonts-extra
                elif command_exists yum; then
                    sudo yum install -y texlive-xetex
                else
                    echo -e "${RED}✗ 无法自动安装 XeLaTeX${NC}"
                fi
            fi
            ;;
        4)
            echo -e "${YELLOW}⊘ 跳过 PDF 引擎安装${NC}"
            echo -e "${BLUE}  提示: 稍后可以手动安装:${NC}"
            echo -e "    macOS: brew install --cask chromium"
            echo -e "    Linux: sudo apt-get install chromium-browser"
            echo -e "    Python: pip3 install weasyprint"
            ;;
        *)
            echo -e "${YELLOW}⊘ 无效选择,跳过安装${NC}"
            ;;
    esac
}

# 创建全局命令链接
install_global_cli() {
    echo -e "${YELLOW}→ 安装全局 CLI 命令...${NC}"
    
    # 创建 bin 目录
    mkdir -p "$SCRIPT_DIR/bin"
    
    # 创建全局命令脚本
    cat > "$SCRIPT_DIR/bin/mdconv" << 'EOF'
#!/bin/bash
# mdconv - Markdown 多格式转换工具
# 支持转换为 DOCX, PDF, HTML, PPTX, EPUB 等格式

# 获取安装目录
INSTALL_DIR="$(cd "$(dirname "$(dirname "$(readlink -f "$0" || echo "$0")")")" && pwd)"

# 检查是否有参数
if [ $# -eq 0 ]; then
    echo "用法: mdconv [选项] <输入文件>"
    echo ""
    echo "选项:"
    echo "  -q, --quick          快速模式（跳过交互）"
    echo "  -f, --format FORMAT  输出格式 (docx|pdf|html|pptx|epub)"
    echo "  -h, --help           显示帮助信息"
    echo ""
    echo "示例:"
    echo "  mdconv document.md                 # 交互式转换（默认）"
    echo "  mdconv -q document.md              # 快速转换为 DOCX"
    echo "  mdconv -q -f pdf document.md       # 快速转换为 PDF"
    exit 1
fi

# 检查是否使用快速模式
if [ "$1" = "-q" ] || [ "$1" = "--quick" ]; then
    shift
    "$INSTALL_DIR/scripts/convert.sh" "$@"
else
    # 默认使用交互式模式
    "$INSTALL_DIR/scripts/convert_interactive.sh" "$@"
fi
EOF

    chmod +x "$SCRIPT_DIR/bin/mdconv"
    
    # 创建向后兼容的别名
    ln -sf mdconv "$SCRIPT_DIR/bin/md2docx"
    
    # 添加到 PATH
    local shell_rc=""
    if [[ -f "$HOME/.zshrc" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        if ! grep -q "mdconv" "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# mdconv - Markdown 多格式转换工具" >> "$shell_rc"
            echo "export PATH=\"$SCRIPT_DIR/bin:\$PATH\"" >> "$shell_rc"
            echo -e "${GREEN}✓ 已添加到 $shell_rc${NC}"
            echo -e "${YELLOW}  请运行: source $shell_rc${NC}"
        fi
    fi
}

# 配置 Hammerspoon (仅 macOS)
configure_hammerspoon() {
    if [[ "$OS" == "macos" ]]; then
        echo -e "${YELLOW}→ 配置 Hammerspoon...${NC}"
        
        # 创建 Hammerspoon 配置目录
        if [[ ! -d "$HOME/.hammerspoon" ]]; then
            mkdir -p "$HOME/.hammerspoon"
        fi
        
        # 复制配置文件到用户目录
        cp "$SCRIPT_DIR/.mdconv.conf" "$HOME/.mdconv.conf"
        echo -e "${GREEN}✓ 配置文件已复制到 ~/.mdconv.conf${NC}"
        
        # 检查 Hammerspoon init.lua 是否存在
        local hammerspoon_init="$HOME/.hammerspoon/init.lua"
        local load_command="dofile(\"$SCRIPT_DIR/hammerspoon/init.lua\")"
        
        if [[ ! -f "$hammerspoon_init" ]]; then
            # 创建新的 init.lua
            cat > "$hammerspoon_init" << EOF
-- Hammerspoon 配置文件
-- 自动生成于 Markdown to DOCX 工具安装

-- 加载 Markdown to DOCX 转换器
$load_command

-- 显示启动消息
hs.alert.show("Hammerspoon 配置已加载")
EOF
            echo -e "${GREEN}✓ 已创建 Hammerspoon 配置文件${NC}"
        else
            # 检查是否已经添加了加载命令
            if ! grep -q "markdown-to-docx" "$hammerspoon_init"; then
                # 添加加载命令
                echo "" >> "$hammerspoon_init"
                echo "-- Markdown to DOCX 转换器" >> "$hammerspoon_init"
                echo "$load_command" >> "$hammerspoon_init"
                echo -e "${GREEN}✓ 已添加到现有 Hammerspoon 配置${NC}"
            else
                echo -e "${GREEN}✓ Hammerspoon 配置已存在${NC}"
            fi
        fi
        
        # 创建配置说明
        cat > "$SCRIPT_DIR/hammerspoon/README.md" << EOF
# Hammerspoon 配置

## 自动配置完成 ✅

安装脚本已自动完成以下配置:

1. ✅ 复制配置文件到 ~/.mdconv.conf
2. ✅ 更新 ~/.hammerspoon/init.lua
3. ✅ 配置项目路径

## 使用方法

### 启动 Hammerspoon
1. 安装 Hammerspoon: https://www.hammerspoon.org/
2. 启动 Hammerspoon 应用
3. 重新加载配置 (Reload Config)

### 使用转换器
- **快捷键**: Cmd+Shift+M
- **菜单栏**: 点击 📄 图标

### 功能
- 选择文件转换
- 批量转换
- 实时进度显示
- 转换完成后打开文件夹

## 故障排除

### 问题: 快捷键无响应
**解决**: 
1. 打开 Hammerspoon Console
2. 查看是否有错误信息
3. 确认配置文件路径正确: \`cat ~/.mdconv.conf\`

### 问题: 提示"请先运行 install.sh"
**解决**:
\`\`\`bash
# 重新运行安装脚本
cd $SCRIPT_DIR
./install.sh
\`\`\`

### 问题: 转换失败
**解决**:
1. 检查依赖: \`./scripts/check_dependencies.sh\`
2. 测试命令行: \`mdconv test.md\`
3. 查看 Hammerspoon Console 日志

## 手动配置 (如果需要)

如果自动配置失败,可以手动添加:

编辑 \`~/.hammerspoon/init.lua\`:
\`\`\`lua
dofile("$SCRIPT_DIR/hammerspoon/init.lua")
\`\`\`

## 卸载

从 \`~/.hammerspoon/init.lua\` 中删除相关行即可。
EOF
        
        echo -e "${GREEN}✓ Hammerspoon 配置完成${NC}"
        echo -e "${BLUE}  配置说明: $SCRIPT_DIR/hammerspoon/README.md${NC}"
        echo -e "${YELLOW}  请启动/重新加载 Hammerspoon 以使用 GUI 界面${NC}"
    fi
}

# 创建配置文件
create_config() {
    echo -e "${YELLOW}→ 创建配置文件...${NC}"
    
    cat > "$SCRIPT_DIR/.mdconv.conf" << EOF
# mdconv 配置文件 - Markdown 多格式转换工具
# 安装路径
INSTALL_DIR="$SCRIPT_DIR"

# Pandoc 配置
PANDOC_HIGHLIGHT_STYLE="github"
PANDOC_MATH_FORMAT="mathml"

# Mermaid 配置
MERMAID_THEME="default"
MERMAID_BACKGROUND="transparent"
MERMAID_WIDTH="1200"
MERMAID_HEIGHT="800"

# 输出配置
DEFAULT_OUTPUT_DIR="."
USE_CUSTOM_TEMPLATE="true"
EOF

    echo -e "${GREEN}✓ 配置文件已创建: .mdconv.conf${NC}"
}

# 创建默认模板
create_default_template() {
    echo -e "${YELLOW}→ 创建默认模板...${NC}"
    "$SCRIPT_DIR/scripts/create_template.sh"
}

# 主安装流程
main() {
    detect_os
    echo ""
    
    echo -e "${BLUE}步骤 1/8: 检查包管理器${NC}"
    install_homebrew
    echo ""
    
    echo -e "${BLUE}步骤 2/8: 安装 Pandoc${NC}"
    install_pandoc
    echo ""
    
    echo -e "${BLUE}步骤 3/8: 安装 Node.js${NC}"
    install_nodejs
    echo ""
    
    echo -e "${BLUE}步骤 4/8: 安装 mermaid-cli${NC}"
    install_mermaid_cli
    echo ""
    
    echo -e "${BLUE}步骤 5/8: 安装 PDF 引擎${NC}"
    install_pdf_engine
    echo ""
    
    echo -e "${BLUE}步骤 6/8: 安装全局 CLI${NC}"
    install_global_cli
    echo ""
    
    echo -e "${BLUE}步骤 7/8: 创建配置文件${NC}"
    create_config
    echo ""
    
    echo -e "${BLUE}步骤 8/8: 创建默认模板${NC}"
    create_default_template
    echo ""
    
    if [[ "$OS" == "macos" ]]; then
        configure_hammerspoon
        echo ""
    fi
    
    echo -e "${GREEN}======================================"
    echo -e "  ✓ 安装完成!"
    echo -e "======================================${NC}"
    echo ""
    echo -e "${BLUE}使用方法:${NC}"
    echo ""
    echo -e "  ${GREEN}命令行:${NC}"
    echo -e "    mdconv document.md"
    echo -e "    mdconv input.md output.docx"
    echo ""
    echo -e "  ${GREEN}批量转换:${NC}"
    echo -e "    $SCRIPT_DIR/scripts/batch_convert.sh *.md"
    echo ""
    if [[ "$OS" == "macos" ]]; then
        echo -e "  ${GREEN}Hammerspoon GUI:${NC}"
        echo -e "    快捷键: Cmd+Shift+M"
        echo -e "    配置: 查看 $SCRIPT_DIR/hammerspoon/README.md"
        echo ""
    fi
    echo -e "${YELLOW}注意: 请重新加载 shell 配置或重启终端以使用 mdconv 命令${NC}"
    echo ""
}

# 运行主程序
main

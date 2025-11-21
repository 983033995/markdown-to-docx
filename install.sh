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
echo "  Markdown to DOCX 安装程序"
echo "======================================${NC}"
echo ""

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        echo -e "${GREEN}✓ 检测到 macOS 系统${NC}"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        echo -e "${GREEN}✓ 检测到 Linux 系统${NC}"
    else
        echo -e "${RED}✗ 不支持的操作系统: $OSTYPE${NC}"
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

# 创建全局命令链接
install_global_cli() {
    echo -e "${YELLOW}→ 安装全局 CLI 命令...${NC}"
    
    # 创建 bin 目录
    mkdir -p "$SCRIPT_DIR/bin"
    
    # 创建全局命令脚本
    cat > "$SCRIPT_DIR/bin/md2docx" << 'EOF'
#!/bin/bash
# Markdown to DOCX 全局命令

# 获取安装目录
INSTALL_DIR="$(cd "$(dirname "$(dirname "$(readlink -f "$0" || echo "$0")")")" && pwd)"

# 调用转换脚本
"$INSTALL_DIR/scripts/convert.sh" "$@"
EOF

    chmod +x "$SCRIPT_DIR/bin/md2docx"
    
    # 添加到 PATH
    local shell_rc=""
    if [[ -f "$HOME/.zshrc" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        if ! grep -q "md2docx" "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# Markdown to DOCX CLI" >> "$shell_rc"
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
        
        if [[ ! -d "$HOME/.hammerspoon" ]]; then
            mkdir -p "$HOME/.hammerspoon"
        fi
        
        # 更新 Hammerspoon 配置中的项目路径
        sed -i.bak "s|projectPath = \".*\"|projectPath = \"$SCRIPT_DIR\"|g" \
            "$SCRIPT_DIR/hammerspoon/init.lua"
        
        # 创建配置说明
        cat > "$SCRIPT_DIR/hammerspoon/README.md" << EOF
# Hammerspoon 配置

## 安装方式

1. 安装 Hammerspoon: https://www.hammerspoon.org/

2. 在 ~/.hammerspoon/init.lua 中添加:

\`\`\`lua
dofile("$SCRIPT_DIR/hammerspoon/init.lua")
\`\`\`

3. 重新加载 Hammerspoon 配置

4. 使用快捷键 Cmd+Shift+M 打开转换器
EOF
        
        echo -e "${GREEN}✓ Hammerspoon 配置已更新${NC}"
        echo -e "${BLUE}  查看配置说明: $SCRIPT_DIR/hammerspoon/README.md${NC}"
    fi
}

# 创建配置文件
create_config() {
    echo -e "${YELLOW}→ 创建配置文件...${NC}"
    
    cat > "$SCRIPT_DIR/.md2docx.conf" << EOF
# Markdown to DOCX 配置文件
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

    echo -e "${GREEN}✓ 配置文件已创建: .md2docx.conf${NC}"
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
    
    echo -e "${BLUE}步骤 1/7: 检查包管理器${NC}"
    install_homebrew
    echo ""
    
    echo -e "${BLUE}步骤 2/7: 安装 Pandoc${NC}"
    install_pandoc
    echo ""
    
    echo -e "${BLUE}步骤 3/7: 安装 Node.js${NC}"
    install_nodejs
    echo ""
    
    echo -e "${BLUE}步骤 4/7: 安装 mermaid-cli${NC}"
    install_mermaid_cli
    echo ""
    
    echo -e "${BLUE}步骤 5/7: 安装全局 CLI${NC}"
    install_global_cli
    echo ""
    
    echo -e "${BLUE}步骤 6/7: 创建配置文件${NC}"
    create_config
    echo ""
    
    echo -e "${BLUE}步骤 7/7: 创建默认模板${NC}"
    create_default_template
    echo ""
    
    if [[ "$OS" == "macos" ]]; then
        configure_hammerspoon
        echo ""
    fi
    
    echo -e "${GREEN}======================================"
    echo "  ✓ 安装完成!"
    echo "======================================${NC}"
    echo ""
    echo -e "${BLUE}使用方法:${NC}"
    echo ""
    echo -e "  ${GREEN}命令行:${NC}"
    echo -e "    md2docx document.md"
    echo -e "    md2docx input.md output.docx"
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
    echo -e "${YELLOW}注意: 请重新加载 shell 配置或重启终端以使用 md2docx 命令${NC}"
    echo ""
}

# 运行主程序
main

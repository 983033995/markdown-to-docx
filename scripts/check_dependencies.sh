#!/bin/bash

# Markdown to DOCX 依赖检查和安装脚本
# 检查并安装所需的工具: Pandoc, mermaid-cli

set -e

echo "======================================"
echo "  Markdown to DOCX 依赖检查工具"
echo "======================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查结果
ALL_INSTALLED=true

# 检查 Homebrew
echo "检查 Homebrew..."
if ! command -v brew &> /dev/null; then
    echo -e "${RED}✗ Homebrew 未安装${NC}"
    echo "请访问 https://brew.sh 安装 Homebrew"
    ALL_INSTALLED=false
else
    echo -e "${GREEN}✓ Homebrew 已安装${NC}"
    BREW_VERSION=$(brew --version | head -n 1)
    echo "  版本: $BREW_VERSION"
fi

echo ""

# 检查 Pandoc
echo "检查 Pandoc..."
if ! command -v pandoc &> /dev/null; then
    echo -e "${YELLOW}✗ Pandoc 未安装${NC}"
    echo "正在安装 Pandoc..."
    if command -v brew &> /dev/null; then
        brew install pandoc
        echo -e "${GREEN}✓ Pandoc 安装完成${NC}"
    else
        echo -e "${RED}无法自动安装,请手动安装 Homebrew 后重试${NC}"
        ALL_INSTALLED=false
    fi
else
    echo -e "${GREEN}✓ Pandoc 已安装${NC}"
    PANDOC_VERSION=$(pandoc --version | head -n 1)
    echo "  版本: $PANDOC_VERSION"
fi

echo ""

# 检查 Node.js (mermaid-cli 需要)
echo "检查 Node.js..."
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}✗ Node.js 未安装${NC}"
    echo "正在安装 Node.js..."
    if command -v brew &> /dev/null; then
        brew install node
        echo -e "${GREEN}✓ Node.js 安装完成${NC}"
    else
        echo -e "${RED}无法自动安装,请手动安装 Homebrew 后重试${NC}"
        ALL_INSTALLED=false
    fi
else
    echo -e "${GREEN}✓ Node.js 已安装${NC}"
    NODE_VERSION=$(node --version)
    echo "  版本: $NODE_VERSION"
fi

echo ""

# 检查 mermaid-cli
echo "检查 mermaid-cli..."
if ! command -v mmdc &> /dev/null; then
    echo -e "${YELLOW}✗ mermaid-cli 未安装${NC}"
    echo "正在安装 mermaid-cli..."
    if command -v npm &> /dev/null; then
        npm install -g @mermaid-js/mermaid-cli
        echo -e "${GREEN}✓ mermaid-cli 安装完成${NC}"
    else
        echo -e "${RED}无法自动安装,请先安装 Node.js${NC}"
        ALL_INSTALLED=false
    fi
else
    echo -e "${GREEN}✓ mermaid-cli 已安装${NC}"
    MMDC_VERSION=$(mmdc --version)
    echo "  版本: $MMDC_VERSION"
fi

echo ""

# 检查 Lua (macOS 自带)
echo "检查 Lua..."
if ! command -v lua &> /dev/null; then
    echo -e "${RED}✗ Lua 未安装 (macOS 应该自带)${NC}"
    ALL_INSTALLED=false
else
    echo -e "${GREEN}✓ Lua 已安装${NC}"
    LUA_VERSION=$(lua -v 2>&1 | head -n 1)
    echo "  版本: $LUA_VERSION"
fi

echo ""
echo "======================================"

if [ "$ALL_INSTALLED" = true ]; then
    echo -e "${GREEN}✓ 所有依赖已安装完成!${NC}"
    echo ""
    echo "您现在可以使用 Markdown to DOCX 转换工具了。"
    exit 0
else
    echo -e "${RED}✗ 部分依赖未安装${NC}"
    echo ""
    echo "请根据上述提示安装缺失的依赖。"
    exit 1
fi

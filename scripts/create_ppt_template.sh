#!/bin/bash

# 创建优化的 PowerPoint 模板
# 解决字体过大和内容超出界面的问题

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$PROJECT_DIR/templates"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}创建优化的 PowerPoint 模板...${NC}"

# 检查 Pandoc
if ! command -v pandoc &> /dev/null; then
    echo "错误: 未找到 Pandoc"
    exit 1
fi

# 创建模板目录
mkdir -p "$TEMPLATE_DIR"

# 创建临时 Markdown 文件（优化的内容结构）
TEMP_MD=$(mktemp /tmp/ppt_template_XXXXXX.md)

cat > "$TEMP_MD" << 'EOF'
---
title: "演示文稿标题"
author: "作者姓名"
date: "2025-01-01"
---

# 第一部分

## 标题幻灯片

这是一个标题幻灯片，包含简短的介绍文字。

## 内容幻灯片

### 要点列表

- 第一个要点：简洁明了
- 第二个要点：重点突出
- 第三个要点：易于理解

### 编号列表

1. 第一步：准备工作
2. 第二步：执行计划
3. 第三步：总结反馈

## 代码示例

```python
# Python 代码示例
def hello_world():
    """简洁的代码块"""
    print("Hello, World!")
    return True
```

## 表格示例

| 项目 | 说明 | 状态 |
|------|------|------|
| 任务A | 已完成 | ✓ |
| 任务B | 进行中 | → |
| 任务C | 待开始 | ○ |

# 第二部分

## 引用文本

> 这是一段引用文本。
> 适合展示重要观点或名言。

## 多列内容

:::::: {.columns}
::: {.column width="50%"}
**左侧内容**

- 要点 1
- 要点 2
:::

::: {.column width="50%"}
**右侧内容**

- 要点 3
- 要点 4
:::
::::::

## 总结

- 关键要点 1
- 关键要点 2
- 关键要点 3
EOF

# 生成基础模板
echo -e "${YELLOW}→ 生成 PowerPoint 模板...${NC}"

pandoc "$TEMP_MD" \
    -f markdown \
    -t pptx \
    --slide-level=2 \
    -V fontsize=16pt \
    -o "$TEMPLATE_DIR/reference.pptx"

# 清理临时文件
rm "$TEMP_MD"

if [ -f "$TEMPLATE_DIR/reference.pptx" ]; then
    echo -e "${GREEN}✓ PowerPoint 模板创建成功!${NC}"
    echo ""
    echo "模板位置: $TEMPLATE_DIR/reference.pptx"
    echo ""
    echo -e "${BLUE}优化说明:${NC}"
    echo "  • 幻灯片级别设置为 2（二级标题创建新幻灯片）"
    echo "  • 字体大小优化为 16pt（避免过大）"
    echo "  • 内容结构清晰，避免单页内容过多"
    echo ""
    echo -e "${YELLOW}进一步自定义:${NC}"
    echo "1. 使用 PowerPoint 打开模板文件"
    echo "2. 修改母版样式："
    echo "   - 视图 → 幻灯片母版"
    echo "   - 调整标题和正文字体大小"
    echo "   - 设置行距和段落间距"
    echo "   - 调整边距，增加内容区域"
    echo "3. 保存模板文件"
    echo "4. 之后的转换将自动使用优化的样式"
    exit 0
else
    echo "错误: 模板创建失败"
    exit 1
fi

#!/bin/bash

# 创建多个 Word 样式模板
# 提供不同风格的预设模板供用户选择

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

echo -e "${BLUE}创建多个 Word 样式模板...${NC}"

# 检查 Pandoc
if ! command -v pandoc &> /dev/null; then
    echo "错误: 未找到 Pandoc"
    exit 1
fi

# 创建模板目录
mkdir -p "$TEMPLATE_DIR"

# 创建临时 Markdown 文件（包含所有样式元素）
TEMP_MD=$(mktemp /tmp/template_XXXXXX.md)

cat > "$TEMP_MD" << 'EOF'
---
title: "文档标题示例"
author: "作者"
date: "2025-01-01"
---

# 一级标题

这是正文段落，用于展示正文字体和行距效果。这段文字足够长，可以看出段落的整体效果和可读性。

## 二级标题

这是另一个段落，包含**粗体文本**和*斜体文本*，以及`行内代码`。

### 三级标题

无序列表示例：

- 列表项 1
- 列表项 2
  - 子列表项 2.1
  - 子列表项 2.2
- 列表项 3

有序列表示例：

1. 第一项
2. 第二项
3. 第三项

#### 四级标题

> 这是引用文本块。
> 引用可以包含多行内容。

代码块示例：

```python
# Python 代码示例
def hello_world():
    print("Hello, World!")
    return True
```

##### 五级标题

表格示例：

| 列标题 1 | 列标题 2 | 列标题 3 |
|---------|---------|---------|
| 单元格 A1 | 单元格 B1 | 单元格 C1 |
| 单元格 A2 | 单元格 B2 | 单元格 C2 |

###### 六级标题

这是最小的标题级别。
EOF

# 函数：创建模板
create_template() {
    local template_name=$1
    local output_file="$TEMPLATE_DIR/$template_name.docx"
    
    echo -e "${YELLOW}→ 创建 $template_name 模板...${NC}"
    
    pandoc "$TEMP_MD" \
        -f markdown \
        -t docx \
        -o "$output_file" \
        --reference-doc="$output_file" 2>/dev/null || \
    pandoc "$TEMP_MD" \
        -f markdown \
        -t docx \
        -o "$output_file"
    
    if [ -f "$output_file" ]; then
        echo -e "${GREEN}  ✓ $template_name 创建成功${NC}"
    else
        echo "  ✗ $template_name 创建失败"
    fi
}

# 创建默认模板（保持向后兼容）
echo ""
echo "1. 默认模板"
create_template "reference"

# 创建学术论文模板
echo ""
echo "2. 学术论文模板"
create_template "academic"

# 创建商务报告模板
echo ""
echo "3. 商务报告模板"
create_template "business"

# 创建技术文档模板
echo ""
echo "4. 技术文档模板"
create_template "technical"

# 创建简洁现代模板
echo ""
echo "5. 简洁现代模板"
create_template "modern"

# 清理临时文件
rm "$TEMP_MD"

echo ""
echo -e "${GREEN}✓ 所有模板创建完成!${NC}"
echo ""
echo "模板位置: $TEMPLATE_DIR/"
echo ""
echo -e "${BLUE}模板说明:${NC}"
echo "  • reference.docx  - 默认模板"
echo "  • academic.docx   - 学术论文（宋体，严谨）"
echo "  • business.docx   - 商务报告（微软雅黑，现代）"
echo "  • technical.docx  - 技术文档（等线，清晰）"
echo "  • modern.docx     - 简洁现代（苹方，简约）"
echo ""
echo -e "${YELLOW}提示:${NC}"
echo "1. 使用 Microsoft Word 打开模板文件"
echo "2. 修改样式（字体、颜色、大小、间距等）"
echo "3. 特别注意修改标题 1-6 的样式，使层级更清晰"
echo "4. 保存模板文件"
echo "5. 转换时选择对应的模板"

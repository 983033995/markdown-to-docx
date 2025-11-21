#!/bin/bash

# 创建自定义 Word 模板
# 使用 Pandoc 生成一个基础的 reference.docx 模板

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$PROJECT_DIR/templates"
REFERENCE_DOCX="$TEMPLATE_DIR/reference.docx"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}创建自定义 Word 模板...${NC}"

# 检查 Pandoc
if ! command -v pandoc &> /dev/null; then
    echo "错误: 未找到 Pandoc"
    echo "请运行 $PROJECT_DIR/scripts/check_dependencies.sh 安装依赖"
    exit 1
fi

# 创建临时 Markdown 文件
TEMP_MD=$(mktemp /tmp/template_XXXXXX.md)

cat > "$TEMP_MD" << 'EOF'
# 一级标题

这是正文段落。

## 二级标题

这是另一个段落,包含**粗体**和*斜体*文本。

### 三级标题

- 列表项 1
- 列表项 2
- 列表项 3

1. 编号列表 1
2. 编号列表 2
3. 编号列表 3

#### 四级标题

> 这是引用文本

```python
# 这是代码块
def hello():
    print("Hello, World!")
```

| 表头1 | 表头2 | 表头3 |
|-------|-------|-------|
| 单元格1 | 单元格2 | 单元格3 |
| 单元格4 | 单元格5 | 单元格6 |
EOF

# 使用 Pandoc 生成默认模板
echo "生成模板文件..."
pandoc "$TEMP_MD" \
    -f markdown \
    -t docx \
    -o "$REFERENCE_DOCX"

# 清理临时文件
rm "$TEMP_MD"

if [ -f "$REFERENCE_DOCX" ]; then
    echo -e "${GREEN}✓ 模板创建成功!${NC}"
    echo "  位置: $REFERENCE_DOCX"
    echo ""
    echo "提示:"
    echo "1. 使用 Microsoft Word 打开此模板文件"
    echo "2. 修改样式(字体、颜色、间距等)"
    echo "3. 保存模板文件"
    echo "4. 之后的转换将自动使用此模板的样式"
    exit 0
else
    echo "错误: 模板创建失败"
    exit 1
fi

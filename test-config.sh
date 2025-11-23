#!/bin/bash

# 测试不同输出格式的配置文件选择
# 用于验证配置文件联动关系

echo "=== 测试 Mermaid 配置文件联动 ==="
echo ""

# 测试文件
TEST_MD="test-mermaid.md"

# 创建测试 Markdown 文件
cat > "$TEST_MD" << 'EOF'
# 测试流程图

```mermaid
flowchart TD
    A[开始] --> B{判断条件}
    B -->|是| C[执行操作A]
    B -->|否| D[执行操作B]
    C --> E[结束]
    D --> E
```
EOF

echo "✓ 创建测试文件: $TEST_MD"
echo ""

# 测试 HTML 输出
echo "1. 测试 HTML 输出..."
pandoc "$TEST_MD" -o test-output.html \
    --lua-filter=filters/mermaid.lua \
    --standalone
if [ -f "test-output.html" ]; then
    echo "   ✓ HTML 输出成功"
    echo "   - 应使用: mermaid-config-html.json"
    echo "   - 应使用: mermaid-html.css"
else
    echo "   ✗ HTML 输出失败"
fi
echo ""

# 测试 PDF 输出
echo "2. 测试 PDF 输出..."
pandoc "$TEST_MD" -o test-output.pdf \
    --lua-filter=filters/mermaid.lua \
    --pdf-engine=xelatex
if [ -f "test-output.pdf" ]; then
    echo "   ✓ PDF 输出成功"
    echo "   - 应使用: mermaid-config-pdf.json"
    echo "   - 应使用: mermaid-pdf.css"
else
    echo "   ✗ PDF 输出失败"
fi
echo ""

# 测试 DOCX 输出
echo "3. 测试 DOCX 输出..."
pandoc "$TEST_MD" -o test-output.docx \
    --lua-filter=filters/mermaid.lua
if [ -f "test-output.docx" ]; then
    echo "   ✓ DOCX 输出成功"
    echo "   - 应使用: mermaid-config-docx.json"
    echo "   - 应使用: mermaid-docx.css"
else
    echo "   ✗ DOCX 输出失败"
fi
echo ""

# 清理
echo "清理测试文件..."
rm -f "$TEST_MD" test-output.html test-output.pdf test-output.docx
echo "✓ 清理完成"
echo ""

echo "=== 测试完成 ==="
echo ""
echo "配置文件说明："
echo "- HTML: 适用于网页显示，使用现代化配色和较大间距"
echo "- PDF:  适用于打印输出，使用高对比度和优化的字体"
echo "- DOCX: 适用于 Word 文档，使用紧凑布局和标准配色"
echo ""
echo "详细说明请查看: docs/配置文件说明.md"

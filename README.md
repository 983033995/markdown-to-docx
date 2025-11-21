# Markdown to DOCX 转换器

一个功能强大的 Markdown 到 DOCX 转换工具,支持 Mermaid 图表、LaTeX 数学公式、代码高亮、表格等丰富元素。

## ✨ 特性

- ✅ **Mermaid 图表支持**: 流程图、时序图、甘特图等自动转换为高质量 SVG
- ✅ **LaTeX 数学公式**: 转换为 Office MathML 格式
- ✅ **代码语法高亮**: 支持多种编程语言的 GitHub 风格高亮
- ✅ **完整 Markdown 支持**: 表格、列表、引用、图片、脚注等
- ✅ **批量转换**: 支持同时转换多个文件
- ✅ **命令行 + GUI**: 既可以命令行使用,也可以通过 Hammerspoon 图形界面操作
- ✅ **自定义样式**: 支持自定义 Word 模板

## 📋 系统要求

- macOS (已在 macOS 上测试)
- Homebrew
- Hammerspoon (用于 GUI 界面)

## 🚀 快速开始

### 1. 安装依赖

运行依赖检查脚本,自动安装所需工具:

```bash
cd /Volumes/13759427003/工具/markdown-to-docx
./scripts/check_dependencies.sh
```

该脚本会自动安装:
- Pandoc (文档转换引擎)
- Node.js (mermaid-cli 依赖)
- mermaid-cli (Mermaid 图表渲染)

### 2. 创建自定义模板 (可选)

生成默认 Word 模板:

```bash
./scripts/create_template.sh
```

然后使用 Microsoft Word 打开 `templates/reference.docx` 修改样式。

### 3. 使用方式

#### 方式一: 命令行转换

**单文件转换:**

```bash
./scripts/convert.sh document.md
# 输出: document.docx (在同目录)
```

**指定输出路径:**

```bash
./scripts/convert.sh input.md output.docx
```

**批量转换:**

```bash
./scripts/batch_convert.sh doc1.md doc2.md doc3.md
# 或使用通配符
./scripts/batch_convert.sh *.md
```

#### 方式二: Hammerspoon GUI 界面

1. **安装 Hammerspoon 配置:**

```bash
# 如果已有 Hammerspoon 配置,添加到现有 init.lua:
# require("markdown-to-docx")

# 或者创建符号链接:
mkdir -p ~/.hammerspoon
ln -s /Volumes/13759427003/工具/markdown-to-docx/hammerspoon/init.lua \
      ~/.hammerspoon/markdown-to-docx.lua
```

2. **在 Hammerspoon 主配置中加载:**

编辑 `~/.hammerspoon/init.lua`,添加:

```lua
require("markdown-to-docx")
```

3. **重新加载 Hammerspoon 配置**

4. **使用界面:**
   - 点击菜单栏的 📄 图标
   - 或使用快捷键 `Cmd+Shift+M`
   - 拖拽文件或点击"选择文件"按钮
   - 点击"开始转换"

## 📖 支持的 Markdown 元素

### 基础元素
- 标题 (H1-H6)
- 段落
- 粗体、斜体、删除线
- 列表 (有序、无序)
- 引用
- 水平线

### 高级元素

#### Mermaid 图表

```markdown
​```mermaid
graph TD
    A[开始] --> B{判断}
    B -->|是| C[执行]
    B -->|否| D[结束]
    C --> D
​```
```

支持的图表类型:
- 流程图 (flowchart, graph)
- 时序图 (sequenceDiagram)
- 甘特图 (gantt)
- 类图 (classDiagram)
- 状态图 (stateDiagram)
- 饼图 (pie)
- 等等...

#### LaTeX 数学公式

行内公式: `$E = mc^2$`

块级公式:
```markdown
$$
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
$$
```

#### 代码块

```markdown
​```python
def hello_world():
    print("Hello, World!")
​```
```

支持语法高亮的语言: Python, JavaScript, Java, C++, Go, Rust, TypeScript, Shell, 等等...

#### 表格

```markdown
| 列1 | 列2 | 列3 |
|-----|-----|-----|
| A   | B   | C   |
| D   | E   | F   |
```

#### 图片

```markdown
![图片描述](image.png)
```

#### 脚注

```markdown
这是一段文字[^1]。

[^1]: 这是脚注内容。
```

## 🎨 自定义样式

### 修改模板

1. 生成默认模板:
   ```bash
   ./scripts/create_template.sh
   ```

2. 使用 Word 打开 `templates/reference.docx`

3. 修改样式:
   - 标题 1-6 样式
   - 正文样式
   - 代码样式
   - 表格样式
   - 等等...

4. 保存模板

5. 之后的转换会自动使用新样式

### 样式建议

- **标题**: 使用清晰的层级结构
- **代码**: 使用等宽字体 (如 Consolas, Monaco)
- **表格**: 设置合适的边框和背景色
- **间距**: 调整段落和行间距

## 🔧 高级配置

### Pandoc 选项

编辑 `scripts/convert.sh`,修改 Pandoc 参数:

```bash
pandoc "$INPUT_FILE" \
    -f markdown \
    -t docx \
    --lua-filter="$FILTER_DIR/mermaid.lua" \
    --highlight-style=github \        # 代码高亮样式
    --mathml \                         # 数学公式格式
    --toc \                            # 添加目录
    --toc-depth=3 \                    # 目录深度
    $REFERENCE_ARG \
    -o "$OUTPUT_FILE"
```

### Mermaid 配置

编辑 `filters/mermaid.lua`,修改 Mermaid 渲染选项:

```lua
local command = string.format(
    "mmdc -i '%s' -o '%s' -b transparent -t default -w 1200 -H 800",
    mmd_file,
    svg_file
)
```

参数说明:
- `-b`: 背景色 (transparent, white, black)
- `-t`: 主题 (default, forest, dark, neutral)
- `-w`: 宽度
- `-H`: 高度

## 📁 项目结构

```
markdown-to-docx/
├── README.md                 # 使用文档
├── scripts/
│   ├── check_dependencies.sh # 依赖检查脚本
│   ├── convert.sh            # 单文件转换脚本
│   ├── batch_convert.sh      # 批量转换脚本
│   └── create_template.sh    # 模板生成脚本
├── filters/
│   └── mermaid.lua           # Mermaid 过滤器
├── templates/
│   └── reference.docx        # Word 样式模板 (生成后)
├── hammerspoon/
│   └── init.lua              # Hammerspoon GUI 脚本
└── examples/
    └── demo.md               # 示例文档
```

## 🐛 故障排除

### Mermaid 图表不显示

1. 检查 mermaid-cli 是否安装:
   ```bash
   mmdc --version
   ```

2. 手动测试 Mermaid 转换:
   ```bash
   echo "graph TD; A-->B;" > test.mmd
   mmdc -i test.mmd -o test.svg
   ```

3. 查看转换日志中的错误信息

### 数学公式显示异常

- 确保使用 `--mathml` 选项
- 某些复杂公式可能需要调整 LaTeX 语法
- 可以尝试使用图片格式: 将 `--mathml` 改为 `--webtex`

### 代码高亮不生效

- 检查代码块是否指定了语言
- 尝试其他高亮样式: `pygments`, `kate`, `monochrome`, `espresso`, `tango`

### 转换速度慢

- Mermaid 图表渲染需要时间
- 大文件建议分批转换
- 可以考虑使用 SSD 存储

## 📝 示例

查看 `examples/demo.md` 获取完整示例。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request!

## 📄 许可

MIT License

## 🙏 致谢

- [Pandoc](https://pandoc.org/) - 强大的文档转换工具
- [Mermaid](https://mermaid-js.github.io/) - 优秀的图表库
- [Hammerspoon](https://www.hammerspoon.org/) - macOS 自动化工具

---

**快速链接:**
- [Pandoc 文档](https://pandoc.org/MANUAL.html)
- [Mermaid 文档](https://mermaid-js.github.io/mermaid/)
- [Markdown 语法](https://www.markdownguide.org/)

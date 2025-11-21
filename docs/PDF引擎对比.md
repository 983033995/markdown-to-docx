# PDF 引擎对比说明

## 支持的 PDF 引擎

本工具支持多种 PDF 引擎，每种引擎都有其特点和适用场景。

### 1. WeasyPrint（推荐，轻量级）

**优点**:
- ✅ 安装快速（约 20MB）
- ✅ 支持中文
- ✅ 足够日常使用
- ✅ 开源免费

**缺点**:
- ⚠️ 不支持部分 CSS3 属性（会显示警告，但不影响转换）
- ⚠️ 数学公式支持有限（会显示警告）
- ⚠️ 排版质量不如 LaTeX

**适用场景**:
- 日常文档转换
- 技术文档
- 简单报告

**常见警告**（可忽略）:
```
WARNING: Ignored `text-rendering: optimizeLegibility`
WARNING: Ignored `overflow-x: auto`
WARNING: Ignored `user-select: none`
WARNING: Could not convert TeX math
```

### 2. Chromium（现代化渲染）

**优点**:
- ✅ 现代化渲染引擎
- ✅ 完整的 CSS3 支持
- ✅ 支持复杂布局
- ✅ 支持中文

**缺点**:
- ⚠️ 体积较大（约 200MB）
- ⚠️ 安装时间较长

**适用场景**:
- 需要复杂 CSS 样式的文档
- 网页转 PDF
- 演示文稿

**安装**:
```bash
brew install --cask chromium
```

### 3. XeLaTeX（专业排版）

**优点**:
- ✅ 专业排版质量
- ✅ 完美的数学公式支持
- ✅ 完美的中文支持
- ✅ 学术论文标准

**缺点**:
- ⚠️ 体积巨大（约 4GB）
- ⚠️ 安装时间很长
- ⚠️ 学习曲线陡峭

**适用场景**:
- 学术论文
- 书籍排版
- 需要复杂数学公式的文档

**安装**:
```bash
brew install --cask mactex-no-gui
```

## 引擎选择建议

### 快速开始
```bash
brew install weasyprint
```

### 需要完美渲染
```bash
brew install --cask chromium
```

### 学术写作
```bash
brew install --cask mactex-no-gui
```

## 引擎检测

工具会自动检测可用的 PDF 引擎，按以下优先级：

1. XeLaTeX（如果已安装）
2. LuaLaTeX
3. PDFLaTeX
4. Chromium
5. WeasyPrint

可以手动指定引擎：
```bash
./scripts/convert_multi.sh -f pdf --pdf-engine weasyprint input.md
```

## 常见问题

### Q: WeasyPrint 的警告信息是否影响转换？
A: 不影响。这些警告只是表示某些 CSS 属性不被支持，但文档仍会正常生成。

### Q: 如何获得最佳 PDF 质量？
A: 使用 XeLaTeX 引擎，但需要安装 MacTeX（约 4GB）。

### Q: 数学公式显示不正确怎么办？
A: WeasyPrint 对数学公式支持有限，建议使用 XeLaTeX 引擎。

### Q: 如何切换 PDF 引擎？
A: 工具会自动检测并使用最佳可用引擎。如需手动指定，使用 `--pdf-engine` 参数。

## 性能对比

| 引擎 | 安装大小 | 安装时间 | 转换速度 | 排版质量 | 中文支持 |
|------|---------|---------|---------|---------|---------|
| WeasyPrint | 20MB | 1-2分钟 | 快 | 良好 | ✅ |
| Chromium | 200MB | 5-10分钟 | 中等 | 优秀 | ✅ |
| XeLaTeX | 4GB | 10-30分钟 | 慢 | 专业 | ✅ |

# 更新日志

## v2.4.0 - 2024-11-23

### 🔗 Excel 集成到 CLI 和 GUI

#### CLI 集成
- ✅ **mdconv 支持 Excel 格式**
  - `mdconv -f xlsx document.md` 直接转换为 Excel
  - 交互式菜单新增 Excel 选项
  - 与其他格式统一的使用体验

#### 后端集成
- ✅ **convert_multi.sh 支持 Excel**
  - 自动调用 md2xlsx.sh
  - 统一的批量转换接口
  - 完整的错误处理

#### 使用示例
```bash
# 命令行直接转换
mdconv -f xlsx tables.md

# 交互式选择 Excel
mdconv tables.md
# 然后在菜单中选择 XLSX

# 批量转换
mdconv -f xlsx *.md
```

---

## v2.3.0 - 2024-11-23

### 🎨 CLI 体验优化

#### UI 函数库
- ✅ **创建统一 UI 库** (`scripts/lib/ui.sh`)
  - 彩色输出函数 (成功/错误/警告/信息)
  - 进度条显示 (文本进度条 + 百分比)
  - 图标支持 (✓ ✗ ⚠ ℹ ⟳ →)
  - 旋转动画
  - 步骤显示
  - 错误详情显示
  - 总结框

#### 批量转换优化
- ✅ **优化 `batch_convert.sh`**
  - 实时进度条显示
  - 彩色状态输出
  - 改进的错误提示
  - 美化的总结界面

#### 使用示例
```bash
# 批量转换显示进度条
./scripts/batch_convert.sh *.md

# 输出示例:
# [==============================] 100% (5/5) document.md
# ✓ 转换完成
# 总文件数: 5
# 成功: 5
# 失败: 0
```

### 🔧 技术实现
- 统一的颜色和图标定义
- 可复用的 UI 组件
- 自动清理资源
- 兼容 bash 3.2+

---

## v2.2.0 - 2024-11-23

### 🎉 新功能

#### Excel 转换支持
- ✅ **Markdown → Excel**: 将 Markdown 表格转换为 Excel 文件
  - 支持单表格和多表格转换
  - 自动检测表格数量,智能选择单/多 sheet 模式
  - 表头自动格式化(加粗、灰色背景、居中对齐)
  - 自动调整列宽
  - 使用标题作为 sheet 名称
  
- ✅ **Excel → Markdown**: 将 Excel 文件转换为 Markdown 表格
  - 支持转换所有 sheet 或指定 sheet
  - 支持按 sheet 名称或索引选择
  - 自动生成标准 Markdown 表格格式
  - 保留表头行

#### 新增工具
- `md2xlsx`: Markdown 表格转 Excel 命令行工具
- `xlsx2md`: Excel 转 Markdown 表格命令行工具

#### 使用示例
```bash
# Markdown → Excel
md2xlsx document.md                    # 自动模式
md2xlsx -m document.md output.xlsx     # 多 sheet 模式
md2xlsx -s document.md                 # 单 sheet 模式

# Excel → Markdown
xlsx2md data.xlsx                      # 转换所有 sheet
xlsx2md -s 1 data.xlsx                 # 转换第一个 sheet
xlsx2md -s "销售数据" data.xlsx        # 转换指定 sheet
```

### 🔧 技术实现
- 使用 Pandoc 提取 Markdown 表格
- 使用 openpyxl 库处理 Excel 文件
- Python 脚本实现表格解析和格式化
- 完整的错误处理和用户提示

---

## v2.1.1 - 2024-11-22

### 🔧 CLI 格式选择优化

#### 修复问题

- ✅ **补全输出格式**: CLI 交互式现在支持完整的 7 种格式
  - 新增: Markdown, TXT (纯文本)
  - 与 GUI 保持一致
  
- ✅ **智能格式过滤**: 自动过滤输入格式,避免自己转自己
  - 检测输入文件格式
  - 动态生成可用输出格式列表
  - 智能选择默认输出格式 (Markdown→DOCX, DOCX→Markdown 等)

- ✅ **多文件批量转换**: 自动检测多文件输入
  - 检测到多个文件时自动切换到批量模式
  - 保留交互式配置选项
  - 无缝切换,用户体验一致

#### 改进

- 📝 显示检测到的输入格式
- 🎯 智能默认格式选择
- 🔄 与 Hammerspoon GUI 逻辑完全一致
- 📦 支持 `mdconv file1.md file2.md file3.md` 批量转换

---

## v2.1.0 - 2024-11-22

### 🎉 重大更新

#### 多格式支持
- ✅ 支持 5 种输出格式：DOCX, PDF, HTML, PPTX, EPUB
- ✅ 格式选择下拉菜单，一键切换
- ✅ 每种格式自动生成对应扩展名的文件

#### 预设配置
- ✅ 8 种预设配置：
  - 自定义
  - 标准文档 (DOCX)
  - 学术论文 (PDF, 带目录和章节编号)
  - 技术报告 (PDF, 带目录)
  - 电子书 (EPUB, 带目录和章节编号)
  - 演示文稿 (PPTX)
  - 网页文章 (HTML, 带目录)
  - 简历 (DOCX)
- ✅ 选择预设自动应用相关配置

#### 文档选项
- ✅ 生成目录 (--toc)
- ✅ 章节编号 (--number-sections)
- ✅ 目录深度配置 (默认 3 级)

#### 格式特定配置
- ✅ **PDF**: 4 种预设 (标准文档、学术论文、技术文档、书籍)
  - 自动配置边距、字体大小、纸张尺寸
- ✅ **HTML**: 3 种主题 (GitHub 风格、简约风格、优雅风格)
- ✅ **DOCX**: 5 种模板 (默认、学术、商务、技术、现代)
- ✅ **PPTX**: 3 种风格 (商务、技术、简约)

#### 配置持久化
- ✅ 自动保存用户配置到 `~/.mdconv_gui.yaml`
- ✅ 下次打开自动恢复上次配置
- ✅ 记住格式、预设、选项等所有设置

#### 界面优化
- ✅ 全新的现代化界面设计
- ✅ 渐变色视觉效果
- ✅ 可折叠的高级选项区域
- ✅ 响应式交互反馈
- ✅ 更大的窗口尺寸 (700x650)

#### 命令构建
- ✅ 使用 `convert_multi.sh` 替代 `batch_convert.sh`
- ✅ 完整的参数传递支持
- ✅ 智能的格式特定参数配置

### 🔧 技术改进

- 重构代码结构，使用 `state` 对象统一管理状态
- 添加 `handleNavigation()` 处理界面交互
- 添加 `buildConvertCommand()` 构建转换命令
- 添加 `loadConfig()` 和 `saveConfig()` 配置管理
- 添加 `applyPreset()` 预设应用逻辑

### 📝 使用说明

1. **快速转换**：
   - 拖拽文件 → 选择格式 → 点击转换
   
2. **使用预设**：
   - 选择预设配置（如"学术论文"）
   - 自动应用最佳配置
   
3. **自定义配置**：
   - 选择"自定义"预设
   - 展开"高级选项"
   - 根据需要调整参数

### 🎯 功能对比

| 功能 | CLI 脚手架 | Hammerspoon GUI |
|------|-----------|----------------|
| 多格式支持 | ✅ | ✅ |
| 预设配置 | ✅ | ✅ |
| 文档选项 | ✅ | ✅ |
| 格式特定配置 | ✅ | ✅ |
| 批量转换 | ✅ | ✅ |
| 配置持久化 | ✅ | ✅ |
| 图形界面 | ❌ | ✅ |
| 快捷键支持 | ❌ | ✅ |

### 🚀 快捷键

- `Cmd+Shift+M`: 打开/关闭转换器窗口

### 📦 兼容性

- 完全兼容现有的 CLI 工具
- 使用相同的转换脚本和配置
- 配置文件独立，不影响 CLI 使用

---

## 升级方法

1. 备份已完成：`init.lua.backup`
2. 重新加载 Hammerspoon 配置
3. 使用 `Cmd+Shift+M` 打开新界面

如遇问题，可恢复备份：
```bash
cd ~/markdown-to-docx/hammerspoon  # 或您的项目路径
cp init.lua.backup init.lua
```

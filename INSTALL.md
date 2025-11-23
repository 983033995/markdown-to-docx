# 安装指南

## 快速安装

### 1. 检查并安装依赖

```bash
cd ~/markdown-to-docx  # 或您的项目路径
./scripts/check_dependencies.sh
```

这个脚本会自动检查并安装:
- Homebrew
- Pandoc
- Node.js
- mermaid-cli

### 2. 配置 Hammerspoon (可选)

如果你想使用图形界面:

#### 方法一: 直接加载

编辑 `~/.hammerspoon/init.lua`,添加:

```lua
-- 加载 Markdown to DOCX 转换器
dofile(os.getenv("HOME") .. "/markdown-to-docx/hammerspoon/init.lua")
```

#### 方法二: 使用符号链接

```bash
# 创建 Hammerspoon 配置目录
mkdir -p ~/.hammerspoon

# 创建符号链接（请替换为您的实际项目路径）
ln -s ~/markdown-to-docx/hammerspoon/init.lua \
      ~/.hammerspoon/markdown-to-docx.lua

# 在主配置中加载
echo 'require("markdown-to-docx")' >> ~/.hammerspoon/init.lua
```

#### 重新加载 Hammerspoon

1. 点击菜单栏的 Hammerspoon 图标
2. 选择 "Reload Config"
3. 应该会看到 "Markdown to DOCX 转换器已启动" 的通知

### 3. 创建自定义模板 (可选)

```bash
./scripts/create_template.sh
```

然后使用 Microsoft Word 打开 `templates/reference.docx` 自定义样式。

## 详细安装步骤

### 安装 Homebrew

如果还没有安装 Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 手动安装依赖

如果自动安装脚本失败,可以手动安装:

```bash
# 安装 Pandoc
brew install pandoc

# 安装 Node.js
brew install node

# 安装 mermaid-cli
npm install -g @mermaid-js/mermaid-cli
```

### 验证安装

```bash
# 检查 Pandoc
pandoc --version

# 检查 Node.js
node --version

# 检查 mermaid-cli
mmdc --version

# 检查 Lua (macOS 自带)
lua -v
```

## 测试安装

### 测试命令行转换

```bash
# 转换示例文件
./scripts/convert.sh examples/demo.md

# 检查输出
ls -lh examples/demo.docx

# 打开查看
open examples/demo.docx
```

### 测试 Hammerspoon 界面

1. 按 `Cmd+Shift+M` 打开界面
2. 或点击菜单栏的 📄 图标
3. 拖拽或选择 `examples/demo.md`
4. 点击"开始转换"

## 故障排除

### Homebrew 安装失败

**问题**: 网络连接问题

**解决方案**:
```bash
# 使用国内镜像
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
```

### mermaid-cli 安装失败

**问题**: npm 权限问题

**解决方案**:
```bash
# 使用 npx 运行 (不需要全局安装)
# 或者修复 npm 权限
sudo chown -R $(whoami) ~/.npm
```

### Hammerspoon 不显示菜单栏图标

**问题**: 配置加载失败

**解决方案**:
1. 检查 Hammerspoon Console 的错误信息
2. 确认路径正确
3. 检查 `init.lua` 语法

### Pandoc 转换失败

**问题**: 找不到过滤器

**解决方案**:
```bash
# 检查过滤器文件
ls -l filters/mermaid.lua

# 检查权限
chmod +x scripts/*.sh
```

## 卸载

如果需要卸载:

```bash
# 删除项目目录
rm -rf ~/markdown-to-docx  # 或您的项目路径

# 移除 Hammerspoon 配置
# 编辑 ~/.hammerspoon/init.lua,删除相关行

# 卸载依赖 (可选)
brew uninstall pandoc
npm uninstall -g @mermaid-js/mermaid-cli
```

## 更新

```bash
# 更新 Pandoc
brew upgrade pandoc

# 更新 mermaid-cli
npm update -g @mermaid-js/mermaid-cli
```

## 系统要求

- **操作系统**: macOS 10.14+
- **磁盘空间**: 约 500MB (包括依赖)
- **内存**: 建议 4GB+
- **Hammerspoon**: 0.9.97+ (用于 GUI)

## 下一步

安装完成后,请查看:
- [README.md](README.md) - 完整使用文档
- [examples/demo.md](examples/demo.md) - 示例文档

开始使用:
```bash
# 转换你的第一个文档
./scripts/convert.sh your-document.md
```

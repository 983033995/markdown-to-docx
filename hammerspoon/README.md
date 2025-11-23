# Hammerspoon 配置

## 自动配置完成 ✅

安装脚本已自动完成以下配置:

1. ✅ 复制配置文件到 ~/.mdconv.conf
2. ✅ 更新 ~/.hammerspoon/init.lua
3. ✅ 配置项目路径

## 使用方法

### 启动 Hammerspoon
1. 安装 Hammerspoon: https://www.hammerspoon.org/
2. 启动 Hammerspoon 应用
3. 重新加载配置 (Reload Config)

### 使用转换器
- **快捷键**: Cmd+Shift+M
- **菜单栏**: 点击 📄 图标

### 功能
- 选择文件转换
- 批量转换
- 实时进度显示
- 转换完成后打开文件夹

## 故障排除

### 问题: 快捷键无响应
**解决**: 
1. 打开 Hammerspoon Console
2. 查看是否有错误信息
3. 确认配置文件路径正确: `cat ~/.mdconv.conf`

### 问题: 提示"请先运行 install.sh"
**解决**:
```bash
# 重新运行安装脚本
cd ~/markdown-to-docx  # 或您的项目路径
./install.sh
```

### 问题: 转换失败
**解决**:
1. 检查依赖: `./scripts/check_dependencies.sh`
2. 测试命令行: `mdconv test.md`
3. 查看 Hammerspoon Console 日志

## 手动配置 (如果需要)

如果自动配置失败,可以手动添加:

编辑 `~/.hammerspoon/init.lua`:
```lua
-- 请替换为您的实际项目路径
dofile(os.getenv("HOME") .. "/markdown-to-docx/hammerspoon/init.lua")
```

## 卸载

从 `~/.hammerspoon/init.lua` 中删除相关行即可。

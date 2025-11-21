-- Markdown to DOCX Hammerspoon 界面
-- 提供图形界面进行 Markdown 到 DOCX 的转换

-- 自动检测项目路径
local function detectProjectPath()
    -- 方法1: 从配置文件读取
    local configFile = os.getenv("HOME") .. "/.md2docx.conf"
    local f = io.open(configFile, "r")
    if f then
        for line in f:lines() do
            local path = line:match('INSTALL_DIR="(.-)"')
            if path then
                f:close()
                return path
            end
        end
        f:close()
    end
    
    -- 方法2: 使用默认路径
    local defaultPath = os.getenv("HOME") .. "/markdown-to-docx"
    local checkFile = defaultPath .. "/scripts/convert.sh"
    local cf = io.open(checkFile, "r")
    if cf then
        cf:close()
        return defaultPath
    end
    
    -- 方法3: 提示用户
    hs.alert.show("请先运行 install.sh 安装 Markdown to DOCX")
    return nil
end

-- 配置
local config = {
    -- 项目路径 (自动检测)
    projectPath = detectProjectPath(),
    
    -- 窗口配置
    windowWidth = 600,
    windowHeight = 400,
    
    -- 支持的文件扩展名
    supportedExtensions = {".md", ".markdown"},
}

-- 检查项目路径是否有效
if not config.projectPath then
    return false
end

-- 全局变量
local mainWindow = nil
local fileListView = nil
local selectedFiles = {}
local convertedFiles = {}  -- 存储转换成功的文件
local isConverting = false
local convertingStatus = ""
local currentFileIndex = 0
local totalFiles = 0

-- 工具函数: 检查文件扩展名
local function isSupportedFile(filename)
    for _, ext in ipairs(config.supportedExtensions) do
        if filename:match(ext .. "$") then
            return true
        end
    end
    return false
end

-- 工具函数: 获取文件名
local function getFileName(path)
    return path:match("^.+/(.+)$") or path
end

-- 工具函数: 显示通知
local function showNotification(title, message, isSuccess)
    hs.notify.new({
        title = title,
        informativeText = message,
        soundName = isSuccess and "Glass" or "Basso"
    }):send()
end

-- 工具函数: 打开文件
local function openFile(filePath)
    hs.execute(string.format("open '%s'", filePath))
    showNotification("已打开文件", getFileName(filePath), true)
end

-- 工具函数: 更新文件列表显示
local function updateFileList()
    if not fileListView then return end
    
    local html = [[
        <html>
        <head>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background: #f5f5f5;
                }
                .file-list {
                    background: white;
                    border-radius: 8px;
                    padding: 15px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }
                .file-item {
                    padding: 10px;
                    margin: 5px 0;
                    background: #f9f9f9;
                    border-radius: 5px;
                    border-left: 3px solid #007AFF;
                }
                .file-name {
                    font-weight: 500;
                    color: #333;
                }
                .file-path {
                    font-size: 12px;
                    color: #666;
                    margin-top: 3px;
                }
                .empty-state {
                    text-align: center;
                    padding: 40px;
                    color: #999;
                }
                .drop-hint {
                    text-align: center;
                    padding: 20px;
                    color: #666;
                    font-size: 14px;
                    background: #e8f4ff;
                    border-radius: 8px;
                    margin-bottom: 15px;
                }
                .converting-status {
                    text-align: center;
                    padding: 15px;
                    background: #fff3cd;
                    border-radius: 8px;
                    margin-bottom: 15px;
                    color: #856404;
                    font-weight: 500;
                }
                .progress-bar {
                    width: 100%;
                    height: 6px;
                    background: #e0e0e0;
                    border-radius: 3px;
                    margin-top: 10px;
                    overflow: hidden;
                }
                .progress-fill {
                    height: 100%;
                    background: #007AFF;
                    transition: width 0.3s ease;
                }
                .converted-files {
                    background: #d4edda;
                    border-radius: 8px;
                    padding: 15px;
                    margin-bottom: 15px;
                    border-left: 4px solid #28a745;
                }
                .converted-title {
                    font-weight: 600;
                    color: #155724;
                    margin-bottom: 10px;
                    font-size: 14px;
                }
                .converted-item {
                    padding: 8px 12px;
                    margin: 5px 0;
                    background: white;
                    border-radius: 5px;
                    cursor: pointer;
                    transition: background 0.2s;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                }
                .converted-item:hover {
                    background: #f8f9fa;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                .converted-name {
                    font-weight: 500;
                    color: #155724;
                    flex: 1;
                }
                .converted-action {
                    color: #007AFF;
                    font-size: 12px;
                    margin-left: 10px;
                }
            </style>
        </head>
        <body>
    ]]
    
    -- 显示转换成功的文件
    if #convertedFiles > 0 then
        html = html .. [[
            <div class="converted-files">
                <div class="converted-title">✅ 转换成功的文件</div>
        ]]
        for i, file in ipairs(convertedFiles) do
            local fileName = getFileName(file)
            html = html .. string.format([[
                <div class="converted-item">
                    <div class="converted-name">📄 %s</div>
                    <div class="converted-action">%s</div>
                </div>
            ]], fileName, file)
        end
        html = html .. '</div>'
    end
    
    -- 显示转换状态
    if isConverting then
        local progress = totalFiles > 0 and (currentFileIndex / totalFiles * 100) or 0
        html = html .. string.format([[
            <div class="converting-status">
                <div>⏳ %s</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: %.1f%%"></div>
                </div>
            </div>
        ]], convertingStatus, progress)
    else
        html = html .. [[
            <div class="drop-hint">
                📄 拖拽 Markdown 文件到此处,或点击下方按钮选择文件
            </div>
        ]]
    end
    
    html = html .. '<div class="file-list">'
    
    if #selectedFiles == 0 then
        html = html .. [[
            <div class="empty-state">
                <p>还没有选择文件</p>
                <p style="font-size: 12px;">支持 .md 和 .markdown 文件</p>
            </div>
        ]]
    else
        for i, file in ipairs(selectedFiles) do
            html = html .. string.format([[
                <div class="file-item">
                    <div class="file-name">%d. %s</div>
                    <div class="file-path">%s</div>
                </div>
            ]], i, getFileName(file), file)
        end
    end
    
    html = html .. [[
            </div>
        </body>
        </html>
    ]]
    
    fileListView:html(html)
end

-- 执行转换
local function convertFiles()
    if #selectedFiles == 0 then
        showNotification("Markdown to DOCX", "请先选择要转换的文件", false)
        return
    end
    
    if isConverting then
        showNotification("Markdown to DOCX", "正在转换中,请稍候...", false)
        return
    end
    
    isConverting = true
    totalFiles = #selectedFiles
    currentFileIndex = 0
    convertingStatus = string.format("正在转换 %d 个文件...", totalFiles)
    updateFileList()
    
    -- 构建命令
    local batchScript = config.projectPath .. "/scripts/batch_convert.sh"
    local filesArg = ""
    for _, file in ipairs(selectedFiles) do
        filesArg = filesArg .. " '" .. file .. "'"
    end
    
    -- 设置完整的 PATH 环境变量
    local pathEnv = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    local command = string.format("export PATH='%s:$PATH'; '%s' %s", pathEnv, batchScript, filesArg)
    
    -- 显示开始通知
    showNotification("Markdown to DOCX", "开始转换 " .. #selectedFiles .. " 个文件...", true)
    
    -- 模拟进度更新(因为无法实时获取批处理脚本的进度)
    local progressTimer = hs.timer.doEvery(0.5, function()
        if isConverting and currentFileIndex < totalFiles then
            currentFileIndex = currentFileIndex + 0.1
            if currentFileIndex > totalFiles then
                currentFileIndex = totalFiles
            end
            convertingStatus = string.format("正在转换... (%d%%)", math.floor(currentFileIndex / totalFiles * 100))
            updateFileList()
        end
    end)
    
    -- 异步执行转换
    hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
        progressTimer:stop()
        isConverting = false
        currentFileIndex = totalFiles
        
        if exitCode == 0 then
            convertingStatus = "转换完成!"
            
            -- 收集转换成功的文件
            convertedFiles = {}
            for _, mdFile in ipairs(selectedFiles) do
                -- 生成对应的 docx 文件路径
                local docxFile = mdFile:gsub("%.md$", ".docx"):gsub("%.markdown$", ".docx")
                -- 检查文件是否存在
                local f = io.open(docxFile, "r")
                if f then
                    f:close()
                    table.insert(convertedFiles, docxFile)
                end
            end
            
            updateFileList()
            hs.timer.doAfter(1, function()
                showNotification("转换完成", "成功转换 " .. #convertedFiles .. " 个文件", true)
                -- 清空待转换文件列表
                selectedFiles = {}
                convertingStatus = ""
                updateFileList()
            end)
        else
            convertingStatus = "转换失败"
            updateFileList()
            showNotification("转换失败", "部分文件转换失败", false)
            print("[Markdown to DOCX] 转换失败详情:")
            print(stdOut)
            if stdErr and stdErr ~= "" then
                print("错误信息:", stdErr)
            end
        end
    end, {"-c", command}):start()
end

-- 选择文件
local function selectFiles()
    local chooser = hs.chooser.new(function(choice)
        if not choice then return end
        
        -- 使用 osascript 打开文件选择对话框
        local script = [[
            tell application "System Events"
                activate
                set selectedFiles to choose file with prompt "选择 Markdown 文件" of type {"md", "markdown"} with multiple selections allowed
                set filePaths to {}
                repeat with aFile in selectedFiles
                    set end of filePaths to POSIX path of aFile
                end repeat
                return filePaths
            end tell
        ]]
        
        local task = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
            if exitCode == 0 and stdOut ~= "" then
                -- 解析返回的文件路径
                for path in stdOut:gmatch("[^\n,]+") do
                    path = path:gsub("^%s+", ""):gsub("%s+$", "")
                    if path ~= "" and isSupportedFile(path) then
                        table.insert(selectedFiles, path)
                    end
                end
                updateFileList()
            end
        end, {"-e", script})
        task:start()
    end)
    
    chooser:choices({{text = "打开文件选择器"}})
    chooser:show()
end

-- 创建主窗口
local function createMainWindow()
    -- 获取屏幕尺寸
    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()
    
    -- 计算窗口位置(居中)
    local x = (screenFrame.w - config.windowWidth) / 2
    local y = (screenFrame.h - config.windowHeight) / 2
    
    -- 创建窗口
    mainWindow = hs.webview.new({
        x = x,
        y = y,
        w = config.windowWidth,
        h = config.windowHeight
    })
    
    -- 设置窗口属性
    mainWindow:windowStyle({"titled", "closable", "miniaturizable", "resizable"})
    mainWindow:windowTitle("Markdown to DOCX 转换器")
    mainWindow:allowTextEntry(false)
    
    -- 创建文件列表视图
    fileListView = mainWindow
    updateFileList()
    
    -- 处理拖拽
    mainWindow:allowNewWindows(false)
    
    -- 创建工具栏按钮
    local toolbar = hs.webview.toolbar.new("mdToDocxToolbar", {
        {
            id = "selectFiles",
            label = "选择文件",
            image = hs.image.imageFromName("NSAddTemplate"),
            fn = function()
                selectFiles()
            end
        },
        {
            id = "clearFiles",
            label = "清空列表",
            image = hs.image.imageFromName("NSTrashEmpty"),
            fn = function()
                selectedFiles = {}
                convertedFiles = {}
                updateFileList()
            end
        },
        {
            id = "convert",
            label = "开始转换",
            image = hs.image.imageFromName("NSRefreshTemplate"),
            fn = function()
                convertFiles()
            end
        },
        {
            id = "openFolder",
            label = "打开文件夹",
            image = hs.image.imageFromName("NSFolder"),
            fn = function()
                if #convertedFiles > 0 then
                    -- 打开第一个文件所在的文件夹
                    local folder = convertedFiles[1]:match("(.+)/[^/]+$")
                    if folder then
                        hs.execute(string.format("open '%s'", folder))
                        showNotification("已打开文件夹", folder, true)
                    end
                else
                    showNotification("提示", "还没有转换成功的文件", false)
                end
            end
        }
    })
    
    mainWindow:attachedToolbar(toolbar)
    
    return mainWindow
end

-- 显示窗口
local function showWindow()
    if not mainWindow then
        createMainWindow()
    end
    mainWindow:show()
end

-- 隐藏窗口
local function hideWindow()
    if mainWindow then
        mainWindow:hide()
    end
end

-- 切换窗口显示
local function toggleWindow()
    if mainWindow and mainWindow:hswindow() and mainWindow:hswindow():isVisible() then
        hideWindow()
    else
        showWindow()
    end
end

-- 初始化
local function init()
    -- 检查项目路径
    local checkScript = config.projectPath .. "/scripts/check_dependencies.sh"
    local f = io.open(checkScript, "r")
    if not f then
        hs.alert.show("错误: 未找到项目路径\n" .. config.projectPath)
        return false
    end
    f:close()
    
    -- 创建菜单栏图标
    local menubar = hs.menubar.new()
    menubar:setTitle("📄")
    menubar:setTooltip("Markdown to DOCX 转换器")
    menubar:setMenu({
        {title = "打开转换器", fn = showWindow},
        {title = "-"},
        {title = "退出", fn = function() menubar:delete() end}
    })
    
    -- 绑定快捷键 (Cmd+Shift+M)
    hs.hotkey.bind({"cmd", "shift"}, "M", toggleWindow)
    
    hs.alert.show("Markdown to DOCX 转换器已启动\n快捷键: Cmd+Shift+M")
    
    return true
end

-- 启动
init()

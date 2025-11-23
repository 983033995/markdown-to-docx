-- Markdown to DOCX Hammerspoon 界面
-- 提供图形界面进行 Markdown 到 DOCX 的转换

-- 自动检测项目路径（动态获取，无硬编码）
local function detectProjectPath()
    -- 方法1: 从当前脚本路径推导（最可靠，优先使用）
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local scriptPath = info.source:match("^@(.+)$")
        if scriptPath then
            -- 脚本在 hammerspoon/init.lua，项目根目录是上一级
            local projectPath = scriptPath:match("(.+)/hammerspoon/init%.lua$")
            if projectPath then
                -- 验证路径是否有效
                local testFile = projectPath .. "/scripts/convert_multi.sh"
                local f = io.open(testFile, "r")
                if f then
                    f:close()
                    return projectPath
                end
            end
        end
    end
    
    -- 方法2: 从用户配置文件读取
    local configFile = os.getenv("HOME") .. "/.mdconv.conf"
    local f = io.open(configFile, "r")
    if f then
        for line in f:lines() do
            local path = line:match('INSTALL_DIR="(.-)"')
            if path and path ~= "" then
                f:close()
                -- 验证路径是否有效
                local testFile = path .. "/scripts/convert_multi.sh"
                local tf = io.open(testFile, "r")
                if tf then
                    tf:close()
                    return path
                end
            end
        end
        f:close()
    end
    
    -- 方法3: 尝试常见安装位置
    local possiblePaths = {
        os.getenv("HOME") .. "/markdown-to-docx",
        os.getenv("HOME") .. "/工具/markdown-to-docx",
        os.getenv("HOME") .. "/Documents/markdown-to-docx",
        "/usr/local/share/markdown-to-docx"
    }
    
    for _, path in ipairs(possiblePaths) do
        local testFile = path .. "/scripts/convert_multi.sh"
        f = io.open(testFile, "r")
        if f then
            f:close()
            return path
        end
    end
    
    -- 方法4: 提示用户
    hs.alert.show("❌ 无法找到项目路径，请检查安装")
    return nil
end

-- 配置
local config = {
    -- 项目路径 (自动检测)
    projectPath = detectProjectPath(),
    
    -- 窗口配置
    windowWidth = 700,
    windowHeight = 650,
    
    -- 支持的文件扩展名
    supportedExtensions = {".md", ".markdown"},
    
    -- 配置文件路径
    configFile = os.getenv("HOME") .. "/.mdconv_gui.yaml",
}

-- 格式定义
local formats = {
    {id = "markdown", name = "Markdown", icon = "📝"},
    {id = "docx", name = "Word 文档", icon = "📄"},
    {id = "pdf", name = "PDF 文档", icon = "📋"},
    {id = "html", name = "网页", icon = "🌐"},
    {id = "txt", name = "纯文本", icon = "📃"},
    {id = "pptx", name = "演示文稿", icon = "📊"},
    {id = "epub", name = "电子书", icon = "📚"},
    {id = "xlsx", name = "Excel 表格", icon = "📊"}
}

-- 预设配置定义
local presets = {
    {id = "custom", name = "自定义", format = nil},
    {id = "standard", name = "标准文档", format = "docx", toc = false, number = false},
    {id = "academic", name = "学术论文", format = "pdf", toc = true, number = true},
    {id = "report", name = "技术报告", format = "pdf", toc = true, number = false},
    {id = "book", name = "电子书", format = "epub", toc = true, number = true},
    {id = "presentation", name = "演示文稿", format = "pptx", toc = false, number = false},
    {id = "web", name = "网页文章", format = "html", toc = true, number = false},
    {id = "resume", name = "简历", format = "docx", toc = false, number = false}
}

-- PDF 预设
local pdfPresets = {
    {id = "standard", name = "标准文档"},
    {id = "academic", name = "学术论文"},
    {id = "technical", name = "技术文档"},
    {id = "book", name = "书籍"}
}

-- HTML 主题
local htmlThemes = {
    {id = "github", name = "GitHub 风格"},
    {id = "simple", name = "简约风格"},
    {id = "elegant", name = "优雅风格"}
}

-- DOCX 模板
local docxTemplates = {
    {id = "reference", name = "默认模板"},
    {id = "academic", name = "学术论文"},
    {id = "business", name = "商务报告"},
    {id = "technical", name = "技术文档"},
    {id = "modern", name = "简洁现代"}
}

-- PPTX 风格
local pptxStyles = {
    {id = "business", name = "商务风格"},
    {id = "technical", name = "技术风格"},
    {id = "simple", name = "简约风格"}
}

-- 检查项目路径是否有效
if not config.projectPath then
    return false
end

-- 全局变量
local mainWindow = nil
local fileListView = nil

-- 全局状态
local state = {
    -- 文件列表
    selectedFiles = {},
    convertedFiles = {},
    failedFiles = {},
    
    -- 转换状态
    isConverting = false,
    convertingStatus = "",
    currentFileIndex = 0,
    totalFiles = 0,
    
    -- 用户配置
    inputFormat = "auto",  -- 输入格式（自动检测）
    currentFormat = "docx",
    currentPreset = "standard",
    enableToc = false,
    enableNumberSections = false,
    tocDepth = 3,
    
    -- 格式特定配置
    pdfPreset = "standard",
    htmlTheme = "github",
    docxTemplate = "reference",
    pptxStyle = "business",
    
    -- 高级选项展开状态
    advancedExpanded = false
}

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

-- 工具函数: 检测输入格式
local function detectInputFormat(filename)
    local ext = filename:match("%.([^%.]+)$")
    if not ext then return "markdown" end
    
    ext = ext:lower()
    
    -- 格式映射表
    local formatMap = {
        -- Markdown
        md = "markdown",
        markdown = "markdown",
        mdown = "markdown",
        mkd = "markdown",
        
        -- Word
        docx = "docx",
        doc = "doc",
        
        -- PDF
        pdf = "pdf",
        
        -- HTML
        html = "html",
        htm = "html",
        
        -- LaTeX
        tex = "latex",
        latex = "latex",
        
        -- PowerPoint
        pptx = "pptx",
        ppt = "pptx",
        
        -- EPUB
        epub = "epub",
        
        -- Excel
        xlsx = "xlsx",
        xls = "xlsx",
        
        -- Plain Text
        txt = "txt",
        text = "txt",
        
        -- reStructuredText
        rst = "rst",
        rest = "rst",
        
        -- Org-mode
        org = "org",
        
        -- Textile
        textile = "textile",
        
        -- MediaWiki
        wiki = "mediawiki",
        mediawiki = "mediawiki"
    }
    
    return formatMap[ext] or "markdown"
end

-- 配置持久化: 加载配置
local function loadConfig()
    local f = io.open(config.configFile, "r")
    if not f then return end
    
    local content = f:read("*all")
    f:close()
    
    -- 简单的 YAML 解析
    for line in content:gmatch("[^\r\n]+") do
        local key, value = line:match("^(%w+):%s*(.+)$")
        if key and value then
            if key == "format" then
                state.currentFormat = value
            elseif key == "preset" then
                state.currentPreset = value
            elseif key == "toc" then
                state.enableToc = (value == "true")
            elseif key == "numberSections" then
                state.enableNumberSections = (value == "true")
            elseif key == "tocDepth" then
                state.tocDepth = tonumber(value) or 3
            elseif key == "pdfPreset" then
                state.pdfPreset = value
            elseif key == "htmlTheme" then
                state.htmlTheme = value
            elseif key == "docxTemplate" then
                state.docxTemplate = value
            elseif key == "pptxStyle" then
                state.pptxStyle = value
            end
        end
    end
end

-- 配置持久化: 保存配置
local function saveConfig()
    local f = io.open(config.configFile, "w")
    if not f then return end
    
    f:write(string.format("format: %s\n", state.currentFormat))
    f:write(string.format("preset: %s\n", state.currentPreset))
    f:write(string.format("toc: %s\n", tostring(state.enableToc)))
    f:write(string.format("numberSections: %s\n", tostring(state.enableNumberSections)))
    f:write(string.format("tocDepth: %d\n", state.tocDepth))
    f:write(string.format("pdfPreset: %s\n", state.pdfPreset))
    f:write(string.format("htmlTheme: %s\n", state.htmlTheme))
    f:write(string.format("docxTemplate: %s\n", state.docxTemplate))
    f:write(string.format("pptxStyle: %s\n", state.pptxStyle))
    
    f:close()
end

-- 应用预设配置
local function applyPreset(presetId)
    for _, preset in ipairs(presets) do
        if preset.id == presetId then
            state.currentPreset = presetId
            if preset.format then
                state.currentFormat = preset.format
            end
            if preset.toc ~= nil then
                state.enableToc = preset.toc
            end
            if preset.number ~= nil then
                state.enableNumberSections = preset.number
            end
            return
        end
    end
end

-- 工具函数: 更新文件列表显示
local function updateFileList()
    if not fileListView then return end
    
    local html = [[
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                :root {
                    /* Matte Mint Dark Palette - Default */
                    --bg-app: #0F0F11;
                    --bg-card: #1C1C1E;
                    --bg-header: rgba(28, 28, 30, 0.9);
                    --border-color: rgba(52, 211, 153, 0.2); /* Mint tint border */
                    
                    --text-primary: #FFFFFF;
                    --text-secondary: #A1A1AA;
                    --text-mono: "SF Mono", "Menlo", "Monaco", "Courier New", monospace;
                    
                    --accent-color: #34D399;
                    --accent-hover: #10B981;
                    --accent-gradient: linear-gradient(135deg, #34D399 0%, #10B981 100%);
                    
                    --danger-color: #EF4444;
                    --success-color: #34D399;
                    
                    --shadow-card: 0 0 20px rgba(52, 211, 153, 0.05); /* Subtle glow */
                    --shadow-glow: 0 0 15px rgba(52, 211, 153, 0.3);
                    
                    --radius-card: 16px; /* Slightly sharper for tech feel */
                    --radius-btn: 4px; /* Techy sharp corners or slight round */
                    --blur-strength: 10px;
                }

                /* Ensure Dark Mode consistency */
                @media (prefers-color-scheme: light) {
                    :root {
                        --bg-app: #0F0F11;
                        --bg-card: #1C1C1E;
                        --bg-header: rgba(28, 28, 30, 0.9);
                        --border-color: rgba(52, 211, 153, 0.2);
                        --text-primary: #FFFFFF;
                        --text-secondary: #A1A1AA;
                    }
                }

                * { margin: 0; padding: 0; box-sizing: border-box; }
                
                body {
                    font-family: "SF Pro Display", -apple-system, BlinkMacSystemFont, sans-serif;
                    background-color: var(--bg-app);
                    /* Tech Grid Background */
                    background-image: 
                        linear-gradient(rgba(52, 211, 153, 0.03) 1px, transparent 1px),
                        linear-gradient(90deg, rgba(52, 211, 153, 0.03) 1px, transparent 1px);
                    background-size: 40px 40px;
                    color: var(--text-primary);
                    -webkit-font-smoothing: antialiased;
                    padding-top: 80px; /* More space for HUD header */
                    min-height: 100vh;
                }

                /* HUD Header Toolbar */
                .header {
                    position: fixed;
                    top: 20px; left: 20px; right: 20px;
                    height: 60px;
                    background-color: var(--bg-header);
                    backdrop-filter: blur(10px);
                    -webkit-backdrop-filter: blur(10px);
                    border: 1px solid var(--border-color);
                    border-radius: 12px;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 0 24px;
                    z-index: 100;
                    box-shadow: 0 10px 30px rgba(0,0,0,0.5);
                }
                
                /* Tech Decorative Lines */
                .header::before {
                    content: '';
                    position: absolute;
                    bottom: -1px; left: 20px; right: 20px;
                    height: 1px;
                    background: linear-gradient(90deg, transparent, var(--accent-color), transparent);
                    opacity: 0.5;
                }
                
                .app-title {
                    font-size: 15px;
                    font-weight: 600;
                    color: var(--text-primary);
                }

                .toolbar-actions {
                    display: flex;
                    gap: 12px;
                }

                .btn {
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    height: 36px;
                    padding: 0 20px;
                    border-radius: 4px; /* Techy angular */
                    font-family: var(--text-mono);
                    font-size: 12px;
                    letter-spacing: 1px;
                    text-transform: uppercase;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.2s;
                    border: 1px solid transparent;
                    gap: 8px;
                    position: relative;
                    overflow: hidden;
                }
                
                .btn-primary {
                    background: rgba(52, 211, 153, 0.1);
                    color: var(--accent-color);
                    border: 1px solid var(--accent-color);
                    box-shadow: 0 0 10px rgba(52, 211, 153, 0.2);
                }
                .btn-primary:hover { 
                    background: var(--accent-color);
                    color: #000;
                    box-shadow: 0 0 20px rgba(52, 211, 153, 0.6);
                }
                
                .btn-secondary {
                    background-color: transparent;
                    border: 1px solid var(--border-color);
                    color: var(--text-secondary);
                }
                .btn-secondary:hover { 
                    border-color: var(--text-primary);
                    color: var(--text-primary);
                    background: rgba(255,255,255,0.05);
                }

                .btn-icon { font-size: 14px; }

                /* Main Content */
                .container {
                    max-width: 700px;
                    margin: 0 auto;
                    padding: 20px;
                }

                /* Section Headers */
                .section-header {
                    font-size: 12px;
                    font-weight: 600;
                    color: var(--text-secondary);
                    text-transform: uppercase;
                    letter-spacing: 0.02em;
                    margin: 24px 0 8px 4px;
                }
                .section-header:first-child { margin-top: 0; }

                /* Cards */
                .card {
                    background-color: var(--bg-card);
                    border-radius: 8px;
                    border: 1px solid var(--border-color);
                    position: relative;
                    transition: all 0.3s ease;
                }
                /* Tech Corner Markers */
                .card::after {
                    content: '';
                    position: absolute;
                    top: 0; right: 0;
                    width: 10px; height: 10px;
                    border-top: 2px solid var(--accent-color);
                    border-right: 2px solid var(--accent-color);
                    opacity: 0.5;
                    border-top-right-radius: 6px;
                }
                .card:hover {
                    transform: translateY(-2px);
                    border-color: var(--accent-color);
                    box-shadow: var(--shadow-glow);
                }
                .card:hover::after { opacity: 1; }

                /* File List Info */
                .file-path {
                    font-family: var(--text-mono);
                    font-size: 11px;
                    color: var(--text-secondary);
                    opacity: 0.7;
                }

                /* Empty State */
                .empty-state {
                    padding: 32px 20px;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    text-align: center;
                    border: 1px dashed var(--border-color);
                    background: rgba(255,255,255,0.02);
                }
                .empty-icon {
                    font-size: 24px;
                    margin-bottom: 12px;
                    color: var(--text-secondary);
                    opacity: 0.5;
                }
                .empty-text {
                    font-size: 14px;
                    font-weight: 500;
                    color: var(--text-primary);
                }

                /* File List */
                .file-list {
                    display: flex;
                    flex-direction: column;
                    gap: 12px;
                }
                
                .file-item {
                    padding: 12px 16px;
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    /* Inherits .card styles */
                }
                
                .file-icon {
                    width: 32px; height: 32px;
                    background: #E8E8ED;
                    border-radius: 6px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 16px;
                }
                @media (prefers-color-scheme: dark) {
                    .file-icon { background: #3A3A3A; }
                }
                
                .file-info { flex: 1; min-width: 0; }
                .file-name { font-size: 14px; font-weight: 500; color: var(--text-primary); margin-bottom: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
                .file-path { font-size: 11px; color: var(--text-secondary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
                /* Animations */
                @keyframes scanline {
                    0% { transform: translateY(-100%); }
                    100% { transform: translateY(100vh); }
                }
                @keyframes slideIn {
                    from { opacity: 0; transform: translateY(20px); }
                    to { opacity: 1; transform: translateY(0); }
                }
                @keyframes pulse {
                    0% { box-shadow: 0 0 0 0 rgba(52, 211, 153, 0.4); }
                    70% { box-shadow: 0 0 0 10px rgba(52, 211, 153, 0); }
                    100% { box-shadow: 0 0 0 0 rgba(52, 211, 153, 0); }
                }
                
                /* Scanline Overlay */
                .scanline {
                    position: fixed;
                    top: 0; left: 0; right: 0; bottom: 0;
                    background: linear-gradient(to bottom, transparent 50%, rgba(0,0,0,0.02) 51%);
                    background-size: 100% 4px;
                    pointer-events: none;
                    z-index: 999;
                }
                .scanline::after {
                    content: "";
                    position: absolute;
                    top: 0; left: 0; right: 0; height: 2px;
                    background: rgba(52, 211, 153, 0.1);
                    animation: scanline 6s linear infinite;
                }

                /* Config Grid */
                .config-grid {
                    display: grid;
                    grid-template-columns: repeat(2, 1fr);
                    gap: 16px;
                    margin-bottom: 20px;
                }
                
                .config-module {
                    background: rgba(255, 255, 255, 0.03);
                    border: 1px solid var(--border-color);
                    border-radius: 8px;
                    padding: 16px;
                    position: relative;
                    transition: all 0.3s ease;
                }
                .config-module:hover {
                    background: rgba(52, 211, 153, 0.05);
                    border-color: var(--accent-color);
                }
                /* Module Corner Accents */
                .config-module::before {
                    content: "";
                    position: absolute;
                    top: -1px; left: -1px;
                    width: 8px; height: 8px;
                    border-top: 2px solid var(--accent-color);
                    border-left: 2px solid var(--accent-color);
                    opacity: 0.5;
                    border-top-left-radius: 4px;
                }
                .config-module::after {
                    content: "";
                    position: absolute;
                    bottom: -1px; right: -1px;
                    width: 8px; height: 8px;
                    border-bottom: 2px solid var(--accent-color);
                    border-right: 2px solid var(--accent-color);
                    opacity: 0.5;
                    border-bottom-right-radius: 4px;
                }

                .module-title {
                    font-size: 11px;
                    color: var(--text-secondary);
                    text-transform: uppercase;
                    letter-spacing: 1px;
                    margin-bottom: 12px;
                    font-family: var(--text-mono);
                }
                
                /* Tech Switch */
                .tech-switch {
                    display: flex;
                    align-items: center;
                    cursor: pointer;
                }
                .tech-switch-input { display: none; }
                .tech-switch-track {
                    width: 40px; height: 20px;
                    background: #111;
                    border: 1px solid var(--border-color);
                    position: relative;
                    margin-right: 12px;
                    transition: all 0.3s;
                }
                .tech-switch-thumb {
                    width: 16px; height: 16px;
                    background: var(--text-secondary);
                    position: absolute;
                    top: 1px; left: 1px;
                    transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
                }
                .tech-switch-input:checked + .tech-switch-track {
                    border-color: var(--accent-color);
                    box-shadow: 0 0 10px rgba(52, 211, 153, 0.2);
                }
                .tech-switch-input:checked + .tech-switch-track .tech-switch-thumb {
                    left: 21px;
                    background: var(--accent-color);
                    box-shadow: 0 0 8px var(--accent-color);
                }

                /* Staggered Animation */
                .animate-entry {
                    animation: slideIn 0.5s ease forwards;
                    opacity: 0;
                }
                .delay-1 { animation-delay: 0.1s; }
                .delay-2 { animation-delay: 0.2s; }
                .delay-3 { animation-delay: 0.3s; }
                .delay-4 { animation-delay: 0.4s; }
                
                /* Pulse Button */
                .btn-pulse {
                    animation: pulse 2s infinite;
                }

                /* Progress */
                .progress-container {
                    padding: 16px;
                    text-align: center;
                }
                .progress-bar-bg {
                    height: 4px;
                    background: #E5E5E5;
                    border-radius: 2px;
                    margin-top: 10px;
                    overflow: hidden;
                }
                @media (prefers-color-scheme: dark) {
                    .progress-bar-bg { background: #3A3A3A; }
                }
                .progress-bar-fill {
                    height: 100%;
                    background: var(--accent-color);
                    transition: width 0.3s;
                }
                .status-text { font-size: 13px; color: var(--text-secondary); }

                /* Success Item */
                .success-item {
                    padding: 12px 16px;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    cursor: pointer;
                    border-bottom: 1px solid var(--border-color);
                }
                .success-item:last-child { border-bottom: none; }
                .success-item:hover { background-color: rgba(0,0,0,0.02); }
                .success-icon { color: var(--success-color); margin-right: 8px; }
                .open-btn { font-size: 12px; color: var(--accent-color); font-weight: 500; }

            </style>
        </head>
        <body>
            <div class="scanline"></div>
            
            <!-- Header Toolbar -->
            <div class="header animate-entry">
                <div class="app-title">系统控制台</div>
                <div class="toolbar-actions">
                    <div class="btn btn-secondary" onclick="window.location.href='add:files'">
                        <span class="btn-icon">＋</span> 添加文件
                    </div>
                    <div class="btn btn-secondary" onclick="window.location.href='clear:list'">
                        <span class="btn-icon">✕</span> 清空列表
                    </div>
                    <div class="btn btn-primary btn-pulse" onclick="window.location.href='convert:start'">
                        <span class="btn-icon">▶</span> 启动转换
                    </div>
                </div>
            </div>

            <div class="container">
    ]]
    
    -- 1. 转换状态
    if state.isConverting then
        local progress = state.totalFiles > 0 and (state.currentFileIndex / state.totalFiles * 100) or 0
        html = html .. [[
            <div class="section-header animate-entry">执行状态</div>
            <div class="card progress-container animate-entry">
                <div id="status-text" class="status-text">]] .. state.convertingStatus .. [[</div>
                <div class="progress-bar-bg">
                    <div id="progress-fill" class="progress-bar-fill" style="width: ]] .. string.format("%.1f%%", progress) .. [["></div>
                </div>
            </div>
        ]]
    end

    -- 2. 成功文件
    if #state.convertedFiles > 0 then
        html = html .. '<div class="section-header animate-entry">任务完成</div>'
        html = html .. '<div class="card animate-entry">'
        for i, file in ipairs(state.convertedFiles) do
            local fileName = getFileName(file)
            html = html .. string.format([[
                <div class="success-item" onclick="window.location.href='openfile:%d'">
                    <div style="display:flex;align-items:center;">
                        <span class="success-icon">✓</span>
                        <span class="file-name">%s</span>
                    </div>
                    <div class="open-btn">打开 >></div>
                </div>
            ]], i, fileName)
        end
        html = html .. '</div>'
    end

    -- 2.2 失败文件
    if #state.failedFiles > 0 then
        html = html .. '<div class="section-header animate-entry" style="color:var(--danger-color);">转换失败</div>'
        html = html .. '<div class="card animate-entry" style="border-color:var(--danger-color);">'
        for i, file in ipairs(state.failedFiles) do
            local fileName = getFileName(file)
            html = html .. string.format([[
                <div class="success-item" style="cursor:default;">
                    <div style="display:flex;align-items:center;">
                        <span class="success-icon" style="color:var(--danger-color);">✕</span>
                        <span class="file-name" style="color:var(--text-secondary);">%s</span>
                    </div>
                    <div class="open-btn" style="color:var(--danger-color);">格式错误</div>
                </div>
            ]], fileName)
        end
        html = html .. '</div>'
    end

    -- 3. 文件列表
    html = html .. '<div class="section-header animate-entry delay-1">目标文件 (' .. #state.selectedFiles .. ')</div>'
    
    if #state.selectedFiles == 0 then
        html = html .. [[
            <div class="card empty-state animate-entry delay-1">
                <div class="empty-icon">⌖</div>
                <div class="empty-text">等待目标载入</div>
                <div style="font-size:12px; opacity:0.5; margin-top:8px;">拖拽文件或点击添加</div>
            </div>
        ]]
    else
        html = html .. '<div class="file-list animate-entry delay-1">'
        for i, file in ipairs(state.selectedFiles) do
            local fileName = getFileName(file)
            html = html .. string.format([[                
                <div class="card file-item">
                    <div class="file-icon">MD</div>
                    <div class="file-info">
                        <div class="file-name">%s</div>
                        <div class="file-path">%s</div>
                    </div>
                    <div class="open-btn" onclick="window.location.href='openfile:%d'">打开 &gt;&gt;</div>
                    <div class="remove-btn" onclick="window.location.href='remove:%d'">✕</div>
                </div>
            ]], fileName, file, i, i)
        end
        html = html .. '</div>'
    end
    
    -- 4. 配置选项 (Tech Grid Layout)
    html = html .. [[
        <div class="section-header animate-entry delay-2">系统参数</div>
        <div class="config-grid animate-entry delay-2">
            
            <!-- Module 1: Output Format -->
            <div class="config-module">
                <div class="module-title">输出格式</div>
                <select onchange="window.location.href='format:' + this.value" style="width:100%; text-align:left; border:1px solid var(--border-color); padding:5px; background:rgba(0,0,0,0.2); color:var(--accent-color);">
    ]]
    -- 过滤掉输入格式，避免自己转自己
    for _, format in ipairs(formats) do
        if format.id ~= state.inputFormat then
            local selected = (format.id == state.currentFormat) and " selected" or ""
            html = html .. string.format('<option value="%s"%s>%s</option>', format.id, selected, format.name)
        end
    end
    html = html .. [[
                </select>
            </div>

            <!-- Module 2: Presets -->
            <div class="config-module">
                <div class="module-title">预设配置</div>
                <select onchange="window.location.href='preset:' + this.value" style="width:100%; text-align:left; border:1px solid var(--border-color); padding:5px; background:rgba(0,0,0,0.2); color:var(--accent-color);">
    ]]
    for _, preset in ipairs(presets) do
        local selected = (preset.id == state.currentPreset) and " selected" or ""
        html = html .. string.format('<option value="%s"%s>%s</option>', preset.id, selected, preset.name)
    end
    html = html .. [[
                </select>
            </div>

    ]]
    
    -- 根据格式决定是否显示 TOC 和编号选项
    -- Excel 格式不需要这些选项
    if state.currentFormat ~= "xlsx" then
        html = html .. [[
            <!-- Module 3: Table of Contents -->
            <div class="config-module">
                <div class="module-title">生成目录</div>
                <label class="tech-switch">
                    <input type="checkbox" class="tech-switch-input" ]] .. (state.enableToc and "checked" or "") .. [[ onchange="window.location.href='option:toc:' + this.checked">
                    <div class="tech-switch-track"><div class="tech-switch-thumb"></div></div>
                    <span style="font-size:12px; color:var(--text-primary);">启用</span>
                </label>
            </div>

            <!-- Module 4: Numbering -->
            <div class="config-module">
                <div class="module-title">自动编号</div>
                <label class="tech-switch">
                    <input type="checkbox" class="tech-switch-input" ]] .. (state.enableNumberSections and "checked" or "") .. [[ onchange="window.location.href='option:numbering:' + this.checked">
                    <div class="tech-switch-track"><div class="tech-switch-thumb"></div></div>
                    <span style="font-size:12px; color:var(--text-primary);">启用</span>
                </label>
            </div>
        ]]
    end
    
    html = html .. [[
    ]]
    
    -- 5. 高级选项 (Merged into Grid, no toggle)
    if state.currentFormat == "pdf" then
        html = html .. [[
            <div class="config-module">
                <div class="module-title">PDF 布局</div>
                <select onchange="window.location.href='pdfPreset:' + this.value" style="width:100%; text-align:left; border:1px solid var(--border-color); padding:5px; background:rgba(0,0,0,0.2); color:var(--accent-color);">
        ]]
        for _, preset in ipairs(pdfPresets) do
            local selected = (preset.id == state.pdfPreset) and " selected" or ""
            html = html .. string.format('<option value="%s"%s>%s</option>', preset.id, selected, preset.name)
        end
        html = html .. '</select></div>'
    elseif state.currentFormat == "html" then
        html = html .. [[
            <div class="config-module">
                <div class="module-title">HTML 主题</div>
                <select onchange="window.location.href='htmlTheme:' + this.value" style="width:100%; text-align:left; border:1px solid var(--border-color); padding:5px; background:rgba(0,0,0,0.2); color:var(--accent-color);">
        ]]
        for _, theme in ipairs(htmlThemes) do
            local selected = (theme.id == state.htmlTheme) and " selected" or ""
            html = html .. string.format('<option value="%s"%s>%s</option>', theme.id, selected, theme.name)
        end
        html = html .. '</select></div>'
    elseif state.currentFormat == "docx" then
        html = html .. [[
            <div class="config-module">
                <div class="module-title">Word 模板</div>
                <select onchange="window.location.href='docxTemplate:' + this.value" style="width:100%; text-align:left; border:1px solid var(--border-color); padding:5px; background:rgba(0,0,0,0.2); color:var(--accent-color);">
        ]]
        for _, template in ipairs(docxTemplates) do
            local selected = (template.id == state.docxTemplate) and " selected" or ""
            html = html .. string.format('<option value="%s"%s>%s</option>', template.id, selected, template.name)
        end
        html = html .. '</select></div>'
    end
    
    html = html .. '</div>' -- End config-grid
    
    html = html .. '</div></body></html>'
    
    fileListView:html(html)
end


-- 检测 PDF 引擎
local function detectPdfEngine()
    -- 强制使用 weasyprint（解决 xelatex 图片文字丢失问题）
    local pathEnv = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/TeX/texbin"
    local command = string.format("export PATH='%s:$PATH'; command -v weasyprint", pathEnv)
    
    local output, status = hs.execute(command)
    
    if output and output:match("weasyprint") then
        return "weasyprint"
    end
    
    -- 如果 weasyprint 不可用，回退到自动检测
    local detectScript = config.projectPath .. "/scripts/detect_pdf_engine.sh"
    command = string.format("export PATH='%s:$PATH'; '%s'", pathEnv, detectScript)
    
    output, status = hs.execute(command)
    
    if output then
        output = output:gsub("%s+$", "") -- 去除尾部空白
        return output ~= "none" and output or nil
    end
    return nil
end

-- 构建转换命令
local function buildConvertCommand(pdfEngine)
    local cmd = config.projectPath .. "/scripts/convert_multi.sh"
    
    -- 输入格式（如果不是 markdown）
    if state.inputFormat and state.inputFormat ~= "markdown" and state.inputFormat ~= "auto" then
        cmd = cmd .. " --input-format " .. state.inputFormat
    end
    
    -- 基础参数
    cmd = cmd .. " -f " .. state.currentFormat
    
    -- 文档选项
    if state.enableToc then
        cmd = cmd .. " --toc --toc-depth " .. state.tocDepth
    end
    if state.enableNumberSections then
        cmd = cmd .. " --number-sections"
    end
    
    -- 格式特定选项
    if state.currentFormat == "pdf" then
        -- 指定检测到的 PDF 引擎
        if pdfEngine then
            cmd = cmd .. " --pdf-engine " .. pdfEngine
        end
        
        -- PDF 预设参数（使用引号包裹参数值以支持空格）
        if state.pdfPreset == "academic" then
            cmd = cmd .. " --margin-top '2.5cm' --margin-bottom '2.5cm'"
            cmd = cmd .. " --margin-left '3cm' --margin-right '3cm'"
            cmd = cmd .. " --fontsize '12pt' --papersize 'a4'"
        elseif state.pdfPreset == "technical" then
            cmd = cmd .. " --margin-top '2cm' --margin-bottom '2cm'"
            cmd = cmd .. " --margin-left '2.5cm' --margin-right '2.5cm'"
            cmd = cmd .. " --fontsize '11pt' --papersize 'a4'"
        elseif state.pdfPreset == "book" then
            cmd = cmd .. " --margin-top '3cm' --margin-bottom '3cm'"
            cmd = cmd .. " --margin-left '3.5cm' --margin-right '2.5cm'"
            cmd = cmd .. " --fontsize '10pt' --papersize 'a5'"
        else -- standard
            cmd = cmd .. " --margin-top '2.5cm' --margin-bottom '2.5cm'"
            cmd = cmd .. " --margin-left '2.5cm' --margin-right '2.5cm'"
            cmd = cmd .. " --fontsize '12pt' --papersize 'a4'"
        end
    elseif state.currentFormat == "html" then
        cmd = cmd .. " --html-css " .. state.htmlTheme
    elseif state.currentFormat == "docx" then
        cmd = cmd .. " --docx-template " .. state.docxTemplate
    end
    
    -- 文件列表
    for _, file in ipairs(state.selectedFiles) do
        cmd = cmd .. " '" .. file .. "'"
    end
    
    return cmd
end

-- 执行转换
local function convertFiles()
    if #state.selectedFiles == 0 then
        showNotification("Markdown 转换器", "请先选择要转换的文件", false)
        return
    end
    
    if state.isConverting then
        showNotification("Markdown 转换器", "正在转换中,请稍候...", false)
        return
    end
    
    -- PDF 格式需要检测引擎
    local pdfEngine = nil
    if state.currentFormat == "pdf" then
        pdfEngine = detectPdfEngine()
        if not pdfEngine then
            -- 显示友好的错误提示
            local message = [[PDF 转换需要安装 PDF 引擎

推荐安装方案（按优先级）：

1. Chromium（推荐，现代化渲染）
   brew install --cask chromium

2. WeasyPrint（轻量级）
   pip3 install weasyprint

3. LaTeX（专业排版，约 4GB）
   brew install --cask mactex-no-gui

安装后即可使用 PDF 转换功能。
或者选择其他格式（DOCX/HTML）进行转换。]]
            
            hs.dialog.blockAlert("PDF 引擎未安装", message, "知道了")
            return
        end
    end
    
    state.isConverting = true
    state.totalFiles = #state.selectedFiles
    state.currentFileIndex = 0
    state.convertingStatus = string.format("正在转换 %d 个文件...", state.totalFiles)
    updateFileList()
    
    -- 构建命令
    local command = buildConvertCommand(pdfEngine)
    
    -- 设置完整的 PATH 环境变量（包括 LaTeX 路径）
    local pathEnv = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/TeX/texbin"
    local fullCommand = string.format("export PATH='%s:$PATH'; %s", pathEnv, command)
    
    -- 显示开始通知
    showNotification("Markdown 转换器", "开始转换 " .. #state.selectedFiles .. " 个文件...", true)
    
    -- 模拟进度更新
    local progressTimer = hs.timer.doEvery(0.1, function()
        if state.isConverting and state.currentFileIndex < state.totalFiles then
            state.currentFileIndex = state.currentFileIndex + 0.05
            if state.currentFileIndex > state.totalFiles then
                state.currentFileIndex = state.totalFiles
            end
            
            local progress = math.floor(state.currentFileIndex / state.totalFiles * 100)
            state.convertingStatus = string.format("正在转换... (%d%%)", progress)
            
            -- 使用 JS 更新 UI，避免闪烁
            local js = string.format([[
                var fill = document.getElementById('progress-fill');
                var text = document.getElementById('status-text');
                if (fill) fill.style.width = '%d%%';
                if (text) text.innerText = '%s';
            ]], progress, state.convertingStatus)
            
            if mainWindow then
                mainWindow:evaluateJavaScript(js)
            end
        end
    end)
    
    -- 异步执行转换
    state.currentTask = hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
        state.currentTask = nil -- 清除引用
        progressTimer:stop()
        state.isConverting = false
        state.currentFileIndex = state.totalFiles
        
        print(string.format("[Markdown 转换器] 任务结束. ExitCode: %d", exitCode))
        
        -- 重置列表
        state.convertedFiles = {}
        state.failedFiles = {}
        
        -- 解析输出以区分成功和失败
        local currentInput = nil
        local currentOutput = nil
        local lines = {}
        
        -- 预处理：将输出按行分割
        for line in (stdOut .. "\n" .. (stdErr or "")):gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        
        for _, line in ipairs(lines) do
            -- 去除 ANSI 颜色代码
            local cleanLine = line:gsub("\27%[[0-9;]*m", "")
            
            -- 匹配 "正在转换: input -> output"
            local input, output = cleanLine:match("正在转换: (.+) %-> (.+)")
            if input then
                currentInput = input:gsub("^%s+", ""):gsub("%s+$", "")
                currentOutput = output:gsub("^%s+", ""):gsub("%s+$", "")
            end
            
            -- 匹配成功或失败
            if cleanLine:match("✓ 成功") then
                if currentOutput then 
                    table.insert(state.convertedFiles, currentOutput) 
                    currentOutput = nil -- 重置以避免重复添加
                end
            elseif cleanLine:match("✗ 失败") then
                if currentInput then 
                    table.insert(state.failedFiles, currentInput) 
                    currentInput = nil -- 重置
                end
            end
        end
        
        -- 如果没有解析到任何文件（可能是脚本报错直接退出），尝试根据 exitCode 判断
        if #state.convertedFiles == 0 and #state.failedFiles == 0 then
            if exitCode == 0 then
                -- 假设全部成功（兼容旧逻辑）
                for _, mdFile in ipairs(state.selectedFiles) do
                    local outputFile = mdFile:gsub("%.md$", "." .. state.currentFormat):gsub("%.markdown$", "." .. state.currentFormat)
                    table.insert(state.convertedFiles, outputFile)
                end
            else
                -- 假设全部失败
                for _, mdFile in ipairs(state.selectedFiles) do
                    table.insert(state.failedFiles, mdFile)
                end
            end
        end
        
        local successCount = #state.convertedFiles
        local failCount = #state.failedFiles
        
        if successCount > 0 or failCount > 0 then
            state.convertingStatus = string.format("完成: %d 成功, %d 失败", successCount, failCount)
            updateFileList()
            saveConfig()
            
            if failCount > 0 then
                showNotification("转换完成 (有失败)", string.format("%d 个成功, %d 个失败", successCount, failCount), false)
            else
                showNotification("转换完成", string.format("成功转换 %d 个文件", successCount), true)
            end
        else
            state.convertingStatus = "转换失败"
            updateFileList()
            
            -- 解析错误信息
            local errorMsg = "转换失败"
            if stdOut and stdOut:match("xelatex not found") then
                errorMsg = "PDF 引擎未找到\n请安装 Chromium、WeasyPrint 或 LaTeX"
            elseif stdOut and stdOut:match("pandoc: command not found") then
                errorMsg = "Pandoc 未安装\n请运行: brew install pandoc"
            elseif stdErr and stdErr ~= "" then
                local keyError = stdErr:match("Error: ([^\n]+)") or stdErr:match("error: ([^\n]+)")
                if keyError then errorMsg = keyError end
            end
            
            hs.dialog.blockAlert("转换失败", errorMsg, "知道了")
            
            print("[Markdown 转换器] 转换失败详情:")
            print("StdOut:", stdOut)
            print("StdErr:", stdErr)
        end
    end, {"-c", fullCommand})
    
    if state.currentTask:start() then
        print("[Markdown 转换器] 转换任务已启动")
    else
        print("[Markdown 转换器] 转换任务启动失败")
        state.isConverting = false
        state.convertingStatus = "启动失败"
        updateFileList()
        hs.dialog.blockAlert("错误", "无法启动转换任务", "确定")
    end
end

-- 选择文件
local function selectFiles()
    local chooser = hs.chooser.new(function(choice)
        if not choice then return end
        
        -- 使用 osascript 打开文件选择对话框（仅支持的输入格式）
        local script = [[
            tell application "System Events"
                activate
                set selectedFiles to choose file with prompt "选择文档文件（支持 Markdown, Word, HTML, TXT 等）" of type {"md", "markdown", "docx", "doc", "html", "htm", "txt", "text", "tex", "epub", "rst", "org"} with multiple selections allowed
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
                    if path ~= "" then
                        -- 检测输入格式
                        local inputFormat = detectInputFormat(path)
                        
                        -- 如果是第一个文件，设置全局输入格式
                        if #state.selectedFiles == 0 then
                            state.inputFormat = inputFormat
                            
                            -- 自动选择输出格式（避免输入输出相同）
                            if state.currentFormat == inputFormat then
                                -- 根据输入格式智能选择输出格式
                                if inputFormat == "markdown" then
                                    state.currentFormat = "docx"  -- Markdown → Word
                                elseif inputFormat == "docx" then
                                    state.currentFormat = "markdown"  -- Word → Markdown
                                elseif inputFormat == "html" then
                                    state.currentFormat = "docx"  -- HTML → Word
                                else
                                    state.currentFormat = "markdown"  -- 其他 → Markdown
                                end
                            end
                        end
                        
                        table.insert(state.selectedFiles, path)
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

-- 处理 URL 导航事件
local function handleNavigation(url)
    local action, value = url:match("^(%w+):(.*)$")
    if not action then return end
    
    if action == "format" then
        state.currentFormat = value
        state.currentPreset = "custom"
        updateFileList()
    elseif action == "preset" then
        applyPreset(value)
        updateFileList()
    elseif action == "toc" then
        state.enableToc = not state.enableToc
        updateFileList()
    elseif action == "number" then
        state.enableNumberSections = not state.enableNumberSections
        updateFileList()
    elseif action == "advanced" then
        state.advancedExpanded = not state.advancedExpanded
        updateFileList()
    elseif action == "pdfPreset" then
        state.pdfPreset = value
        updateFileList()
    elseif action == "htmlTheme" then
        state.htmlTheme = value
        updateFileList()
    elseif action == "docxTemplate" then
        state.docxTemplate = value
        updateFileList()
    elseif action == "pptxStyle" then
        state.pptxStyle = value
        updateFileList()
    elseif action == "openfile" then
        -- 打开文件（通过索引）
        local index = tonumber(value)
        local filePath = nil
        if index and state.convertedFiles[index] then
            filePath = state.convertedFiles[index]
        elseif index and state.selectedFiles[index] then
            filePath = state.selectedFiles[index]
        end
        if filePath then
            print("[打开文件] " .. filePath)
            hs.execute(string.format("open '%s'", filePath))
            showNotification("打开文件", getFileName(filePath), true)
        end
    elseif action == "remove" then
        -- 移除文件（通过索引）
        local index = tonumber(value)
        if index and state.selectedFiles[index] then
            table.remove(state.selectedFiles, index)
            updateFileList()
        end
    elseif action == "add" then
        selectFiles()
    elseif action == "clear" then
        state.selectedFiles = {}
        state.convertedFiles = {}
        updateFileList()
    elseif action == "convert" then
        convertFiles()
    end
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
    mainWindow:windowTitle("Markdown 多格式转换器")
    mainWindow:allowTextEntry(false)
    mainWindow:allowNewWindows(false)
    
    -- 设置 URL 拦截处理
    mainWindow:policyCallback(function(action, webView, userInfo)
        if action == "navigationAction" then
            local url = userInfo.request.URL
            -- 打印调试信息
            print("[URL] " .. (url or "nil"))
            
            if url and url:match("^%w+:") and not url:match("^http") and not url:match("^about") and not url:match("^file://") then
                print("[处理自定义 URL] " .. url)
                handleNavigation(url)
                return false
            end
        end
        return true
    end)
    
    -- 创建文件列表视图
    fileListView = mainWindow
    updateFileList()
    
    -- 移除原生工具栏，使用 HTML 头部替代
    -- local toolbar = hs.webview.toolbar.new("mdToDocxToolbar", { ... })
    -- mainWindow:attachedToolbar(toolbar)
    
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
    
    -- 加载用户配置
    loadConfig()
    
    -- 创建菜单栏图标
    local menubar = hs.menubar.new()
    menubar:setTitle("📄")
    menubar:setTooltip("Markdown 多格式转换器")
    menubar:setMenu({
        {title = "打开转换器", fn = showWindow},
        {title = "-"},
        {title = "退出", fn = function() menubar:delete() end}
    })
    
    -- 绑定快捷键 (Cmd+Shift+M)
    hs.hotkey.bind({"cmd", "shift"}, "M", toggleWindow)
    
    hs.alert.show("Markdown 多格式转换器已启动\n快捷键: Cmd+Shift+M")
    
    return true
end

-- 启动
init()

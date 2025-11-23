-- Mermaid 图表转换的 Pandoc Lua 过滤器
-- 根据输出格式选择 PNG 或 SVG
-- HTML 格式使用 SVG（保持矢量图），其他格式使用 PNG（更好的兼容性）

local system = require 'pandoc.system'

-- 临时文件计数器
local mermaid_counter = 0

-- 获取输出格式
local output_format = FORMAT or "docx"

-- 根据输出格式获取配置文件路径
local function get_config_files()
    local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
    local format_suffix = ""
    
    -- 根据输出格式确定配置文件后缀
    if output_format == "html" or output_format == "html5" then
        format_suffix = "-html"
    elseif output_format == "latex" or output_format == "pdf" then
        format_suffix = "-pdf"
    else
        format_suffix = "-docx"
    end
    
    return {
        config = script_dir .. "mermaid-config" .. format_suffix .. ".json",
        css = script_dir .. "mermaid" .. format_suffix .. ".css",
        puppeteer = script_dir .. "puppeteer-config.json"
    }
end

-- 获取临时目录
local function get_temp_dir()
    local temp = os.getenv("TMPDIR") or "/tmp"
    return temp:gsub("/$", "") -- 移除末尾的斜杠
end

-- 生成唯一的临时文件名
local function get_temp_filename(extension)
    mermaid_counter = mermaid_counter + 1
    local temp_dir = get_temp_dir()
    return string.format("%s/mermaid_%d_%d.%s", 
        temp_dir, 
        os.time(), 
        mermaid_counter, 
        extension)
end

-- 执行系统命令并返回结果
local function execute_command(command)
    local handle = io.popen(command .. " 2>&1")
    local result = handle:read("*a")
    local success = handle:close()
    return success, result
end

-- 将 Mermaid 代码转换为 SVG 并返回内容 (用于 HTML)
local function mermaid_to_svg_content(code)
    -- 创建临时文件
    local mmd_file = get_temp_filename("mmd")
    local svg_file = get_temp_filename("svg")
    
    -- 写入 Mermaid 代码到临时文件
    local file = io.open(mmd_file, "w")
    if not file then
        io.stderr:write("错误: 无法创建临时文件 " .. mmd_file .. "\n")
        return nil
    end
    file:write(code)
    file:close()
    
    -- 获取配置文件路径（根据输出格式自动选择）
    local config_files = get_config_files()
    local config_file = config_files.config
    local puppeteer_config = config_files.puppeteer
    local css_file = config_files.css
    
    -- 使用 mermaid-cli 转换为 SVG
    -- 不设置宽高限制，保持 SVG 的矢量特性
    local mmdc_path = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin/mmdc"
    local node_path = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin"
    local command = string.format(
        "export PATH='%s:$PATH' && %s -i '%s' -o '%s' -b transparent -t default -c '%s' -p '%s' -C '%s' 2>&1",
        node_path,
        mmdc_path,
        mmd_file,
        svg_file,
        config_file,
        puppeteer_config,
        css_file
    )
    
    local success, output = execute_command(command)
    
    -- 清理临时 mmd 文件
    os.remove(mmd_file)
    
    if not success then
        io.stderr:write("Mermaid 转换失败:\n" .. output .. "\n")
        return nil
    end
    
    -- 读取 SVG 内容
    local svg_content_file = io.open(svg_file, "r")
    if not svg_content_file then
        io.stderr:write("错误: SVG 文件未生成 " .. svg_file .. "\n")
        return nil
    end
    
    local svg_content = svg_content_file:read("*all")
    svg_content_file:close()
    
    -- 清理临时 SVG 文件
    os.remove(svg_file)
    
    -- 优化 SVG：添加样式控制尺寸
    -- 1. 添加容器样式：限制最大宽度，自动缩放
    -- 2. 添加缩放：将 SVG 缩小到 70% 使节点更紧凑
    svg_content = svg_content:gsub('<svg', '<svg style="max-width: 800px; width: 70%%; height: auto; display: block; margin: 1em auto;"')
    
    return svg_content
end

-- 分析 Mermaid 代码中的文本复杂度
local function analyze_text_complexity(code)
    local max_text_length = 0
    local node_count = 0
    local total_text_length = 0
    
    -- 匹配节点定义: A[文本], B(文本), C{文本}, D((文本)) 等
    for text in code:gmatch("%[([^%]]+)%]") do
        node_count = node_count + 1
        local len = #text
        total_text_length = total_text_length + len
        if len > max_text_length then
            max_text_length = len
        end
    end
    
    for text in code:gmatch("%(([^%)]+)%)") do
        if not text:match("^%s*$") then  -- 排除空括号
            node_count = node_count + 1
            local len = #text
            total_text_length = total_text_length + len
            if len > max_text_length then
                max_text_length = len
            end
        end
    end
    
    for text in code:gmatch("{([^}]+)}") do
        node_count = node_count + 1
        local len = #text
        total_text_length = total_text_length + len
        if len > max_text_length then
            max_text_length = len
        end
    end
    
    local avg_text_length = node_count > 0 and (total_text_length / node_count) or 0
    
    return {
        max_length = max_text_length,
        node_count = node_count,
        avg_length = avg_text_length,
        has_long_text = max_text_length > 20
    }
end

-- 将 Mermaid 代码转换为 PNG (更好的 Word/PDF 兼容性)
local function mermaid_to_png(code)
    -- 创建临时文件
    local mmd_file = get_temp_filename("mmd")
    local png_file = get_temp_filename("png")
    
    -- 写入 Mermaid 代码到临时文件
    local file = io.open(mmd_file, "w")
    if not file then
        io.stderr:write("错误: 无法创建临时文件 " .. mmd_file .. "\n")
        return nil
    end
    file:write(code)
    file:close()
    
    -- 分析文本复杂度
    local complexity = analyze_text_complexity(code)
    
    -- 基础尺寸
    local width = 1200
    local height = 800
    
    -- 检测图表类型,设置合适的宽度和高度
    -- 检测横向图表
    if code:match("^%s*gantt") or code:match("^%s*sequenceDiagram") then
        -- 甘特图和时序图通常是横向的,需要更大宽度
        width = 2400
        height = 1200
    elseif code:match("^%s*graph%s+LR") or code:match("^%s*flowchart%s+LR") then
        -- 横向流程图
        width = 2000
        height = 1000
    -- 检测纵向流程图
    elseif code:match("^%s*graph%s+TD") or code:match("^%s*flowchart%s+TD") or 
           code:match("^%s*graph%s+TB") or code:match("^%s*flowchart%s+TB") then
        -- 纵向流程图,增加高度
        width = 1400
        height = 2000  -- 大幅增加高度
    end
    
    -- 动态调整画布尺寸
    -- 1. 根据最长文本调整
    if complexity.has_long_text then
        local text_factor = 1 + math.min((complexity.max_length - 20) / 40, 0.5)
        width = math.floor(width * text_factor)
        io.stderr:write(string.format("检测到长文本(最长%d字符),宽度调整系数: %.2f\n", 
            complexity.max_length, text_factor))
    end
    
    -- 2. 根据节点数量调整
    if complexity.node_count > 8 then
        local node_factor = 1 + math.min((complexity.node_count - 8) / 25, 0.4)
        width = math.floor(width * node_factor)
        height = math.floor(height * node_factor)
        io.stderr:write(string.format("检测到较多节点(%d个),尺寸调整系数: %.2f\n", 
            complexity.node_count, node_factor))
    end
    
    -- 3. 限制最大尺寸(避免文件过大)
    local max_width = 3200
    local max_height = 2800
    if width > max_width then
        width = max_width
        io.stderr:write("宽度达到上限,限制为 " .. max_width .. "\n")
    end
    if height > max_height then
        height = max_height
        io.stderr:write("高度达到上限,限制为 " .. max_height .. "\n")
    end
    
    io.stderr:write(string.format("最终画布尺寸: %dx%d\n", width, height))
    
    -- 获取配置文件路径（根据输出格式自动选择）
    local config_files = get_config_files()
    local config_file = config_files.config
    local puppeteer_config = config_files.puppeteer
    local css_file = config_files.css
    
    -- 使用 mermaid-cli 转换为 PNG
    -- -s 2: 2倍分辨率(平衡质量和文件大小)
    -- -w/-H: 设置画布大小
    -- -c: 使用配置文件
    local mmdc_path = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin/mmdc"
    local node_path = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin"
    local command = string.format(
        "export PATH='%s:$PATH' && %s -i '%s' -o '%s' -b transparent -t default -s 2 -w %d -H %d -c '%s' -p '%s' -C '%s' 2>&1",
        node_path,
        mmdc_path,
        mmd_file,
        png_file,
        width,
        height,
        config_file,
        puppeteer_config,
        css_file
    )
    
    local success, output = execute_command(command)
    
    -- 清理临时 mmd 文件
    os.remove(mmd_file)
    
    if not success then
        io.stderr:write("Mermaid 转换失败:\n" .. output .. "\n")
        return nil
    end
    
    -- 检查 PNG 文件是否生成
    local png_content_file = io.open(png_file, "r")
    if not png_content_file then
        io.stderr:write("错误: PNG 文件未生成 " .. png_file .. "\n")
        return nil
    end
    png_content_file:close()
    
    return png_file
end

-- 处理代码块
function CodeBlock(block)
    -- 只处理 mermaid 类型的代码块
    if block.classes[1] == "mermaid" then
        io.stderr:write("处理 Mermaid 图表...\n")
        io.stderr:write("当前输出格式: " .. output_format .. "\n")
        
        -- 根据输出格式选择 SVG 或 PNG
        if output_format == "html" or output_format == "html5" then
            -- HTML 格式：直接内联 SVG 代码
            local svg_content = mermaid_to_svg_content(block.text)
            
            if svg_content then
                io.stderr:write("成功生成 SVG 内联代码\n")
                io.stderr:write("使用 SVG 格式，保持矢量图特性\n")
                
                -- 返回原始 HTML 块，直接嵌入 SVG
                return pandoc.RawBlock("html", svg_content)
            else
                -- 转换失败,保留原始代码块
                io.stderr:write("Mermaid 转换失败,保留原始代码块\n")
                return block
            end
        elseif output_format == "latex" or output_format == "pdf" then
            -- PDF 格式：使用 SVG 文件（保留文字）
            local mmd_file = get_temp_filename("mmd")
            local svg_file = get_temp_filename("svg")
            
            -- 写入 Mermaid 代码
            local file = io.open(mmd_file, "w")
            if not file then
                io.stderr:write("错误: 无法创建临时文件 " .. mmd_file .. "\n")
                return block
            end
            file:write(block.text)
            file:close()
            
            -- 获取配置文件（根据输出格式自动选择）
            local config_files = get_config_files()
            local config_file = config_files.config
            local puppeteer_config = config_files.puppeteer
            local css_file = config_files.css
            
            -- 生成 SVG
            local mmdc_path = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin/mmdc"
            local node_path = "/Users/zhangheteng/.nvm/versions/node/v24.11.1/bin"
            local command = string.format(
                "export PATH='%s:$PATH' && %s -i '%s' -o '%s' -b transparent -t default -c '%s' -p '%s' -C '%s' 2>&1",
                node_path,
                mmdc_path,
                mmd_file,
                svg_file,
                config_file,
                puppeteer_config,
                css_file
            )
            
            local success, output = execute_command(command)
            os.remove(mmd_file)
            
            if success then
                io.stderr:write("成功生成 SVG: " .. svg_file .. "\n")
                io.stderr:write("PDF 使用 SVG 格式以保留文字\n")
                
                -- 返回图片元素
                local img = pandoc.Image({}, svg_file, "", {})
                img.attributes.width = "6.5in"
                
                return pandoc.Para({img})
            else
                io.stderr:write("Mermaid 转换失败: " .. output .. "\n")
                return block
            end
        else
            -- 其他格式使用 PNG（更好的兼容性）
            local png_file = mermaid_to_png(block.text)
            
            if png_file then
                io.stderr:write("成功生成 PNG: " .. png_file .. "\n")
                
                -- 返回图片元素
                local img = pandoc.Image({}, png_file, "", {})
                
                -- PNG 格式：设置适合文档的尺寸
                -- A4 纸张标准页边距后的可用宽度约为 6.5 英寸
                img.attributes.width = "6.5in"
                
                -- 检测流程图复杂度(通过代码行数估算)
                local line_count = 0
                for _ in block.text:gmatch("[^\r\n]+") do
                    line_count = line_count + 1
                end
                
                -- 对于特别长的纵向流程图,设置最大高度并添加提示
                if block.text:match("^%s*graph%s+TD") or block.text:match("^%s*flowchart%s+TD") or 
                   block.text:match("^%s*graph%s+TB") or block.text:match("^%s*flowchart%s+TB") then
                    if line_count > 30 then
                        -- 超长流程图:不限制高度,保持完整显示
                        io.stderr:write("警告: 检测到超长纵向流程图(" .. line_count .. "行),可能跨页显示\n")
                        -- 不设置 height,让图片完整显示
                    else
                        -- 普通纵向流程图:限制最大高度为 9 英寸(约一页高度)
                        img.attributes.height = "9in"
                    end
                end
                
                return pandoc.Para({img})
            else
                -- 转换失败,保留原始代码块
                io.stderr:write("Mermaid 转换失败,保留原始代码块\n")
                return block
            end
        end
    end
    
    -- 其他代码块不处理
    return block
end

-- 返回过滤器
return {
    {CodeBlock = CodeBlock}
}

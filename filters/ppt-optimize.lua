-- PowerPoint 内容优化过滤器
-- 解决内容过多、字体过大、超出界面的问题

-- 计算段落/列表的行数
local function count_lines(blocks)
    local count = 0
    for _, block in ipairs(blocks) do
        if block.t == "Para" or block.t == "Plain" then
            count = count + 1
        elseif block.t == "BulletList" or block.t == "OrderedList" then
            for _, item in ipairs(block.content) do
                count = count + #item
            end
        elseif block.t == "CodeBlock" then
            -- 代码块按行数计算
            local lines = 0
            for _ in block.text:gmatch("[^\r\n]+") do
                lines = lines + 1
            end
            count = count + lines
        end
    end
    return count
end

-- 分割过长的内容
local function split_long_content(blocks, max_lines)
    local result = {}
    local current_slide = {}
    local current_lines = 0
    
    for _, block in ipairs(blocks) do
        local block_lines = 1
        
        if block.t == "BulletList" or block.t == "OrderedList" then
            block_lines = 0
            for _, item in ipairs(block.content) do
                block_lines = block_lines + #item
            end
        elseif block.t == "CodeBlock" then
            block_lines = 0
            for _ in block.text:gmatch("[^\r\n]+") do
                block_lines = block_lines + 1
            end
        end
        
        -- 如果添加这个块会超过限制，创建新幻灯片
        if current_lines + block_lines > max_lines and #current_slide > 0 then
            table.insert(result, current_slide)
            current_slide = {}
            current_lines = 0
        end
        
        table.insert(current_slide, block)
        current_lines = current_lines + block_lines
    end
    
    -- 添加最后一个幻灯片
    if #current_slide > 0 then
        table.insert(result, current_slide)
    end
    
    return result
end

-- 优化列表项，避免过长
local function optimize_list_item(item)
    local result = {}
    for _, block in ipairs(item) do
        if block.t == "Para" or block.t == "Plain" then
            -- 如果段落文字过长，可以在这里添加截断或换行逻辑
            table.insert(result, block)
        else
            table.insert(result, block)
        end
    end
    return result
end

-- 优化代码块，限制行数
local function optimize_code_block(code_text, max_lines)
    local lines = {}
    local count = 0
    
    for line in code_text:gmatch("[^\r\n]+") do
        count = count + 1
        if count <= max_lines then
            table.insert(lines, line)
        else
            table.insert(lines, "... (内容过长，已省略)")
            break
        end
    end
    
    return table.concat(lines, "\n")
end

-- 处理标题级别，确保内容合理分页
function Header(el)
    -- 如果是 3 级或更低级别的标题，可能需要提升为 2 级
    -- 以创建新的幻灯片，避免内容堆积
    if el.level >= 3 then
        -- 保持原样，但可以根据需要调整
        return el
    end
    return el
end

-- 处理列表，优化显示
function BulletList(el)
    -- 如果列表项过多，可以考虑分割
    local max_items_per_slide = 8
    
    if #el.content > max_items_per_slide then
        io.stderr:write("警告: 列表项过多 (" .. #el.content .. " 项)，建议分割\n")
    end
    
    -- 优化每个列表项
    local optimized = {}
    for _, item in ipairs(el.content) do
        table.insert(optimized, optimize_list_item(item))
    end
    
    el.content = optimized
    return el
end

function OrderedList(el)
    -- 与 BulletList 类似的处理
    local max_items_per_slide = 8
    
    if #el.content > max_items_per_slide then
        io.stderr:write("警告: 编号列表项过多 (" .. #el.content .. " 项)，建议分割\n")
    end
    
    local optimized = {}
    for _, item in ipairs(el.content) do
        table.insert(optimized, optimize_list_item(item))
    end
    
    el.content = optimized
    return el
end

-- 处理代码块，限制长度
function CodeBlock(el)
    local max_lines = 15
    local line_count = 0
    
    for _ in el.text:gmatch("[^\r\n]+") do
        line_count = line_count + 1
    end
    
    if line_count > max_lines then
        io.stderr:write("警告: 代码块过长 (" .. line_count .. " 行)，已截断至 " .. max_lines .. " 行\n")
        el.text = optimize_code_block(el.text, max_lines)
    end
    
    return el
end

-- 处理段落，确保不会过长
function Para(el)
    -- 计算段落长度
    local text_length = 0
    for _, inline in ipairs(el.content) do
        if inline.t == "Str" then
            text_length = text_length + #inline.text
        elseif inline.t == "Space" then
            text_length = text_length + 1
        end
    end
    
    -- 如果段落过长（超过 300 字符），给出警告
    if text_length > 300 then
        io.stderr:write("警告: 段落过长 (" .. text_length .. " 字符)，建议分割\n")
    end
    
    return el
end

-- 返回过滤器
return {
    {Header = Header},
    {BulletList = BulletList},
    {OrderedList = OrderedList},
    {CodeBlock = CodeBlock},
    {Para = Para}
}

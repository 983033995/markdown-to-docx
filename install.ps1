# Markdown to DOCX 自动安装脚本 (Windows PowerShell)
# 支持 Windows 10/11

# 设置错误处理
$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Blue "======================================"
Write-ColorOutput Blue "  Markdown to DOCX 安装程序 (Windows)"
Write-ColorOutput Blue "======================================"
Write-Output ""

# 获取脚本所在目录
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# 检测操作系统
Write-ColorOutput Green "✓ 检测到 Windows 系统"
Write-Output ""

# 检查命令是否存在
function Test-CommandExists {
    param($command)
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# 安装 Chocolatey (Windows 包管理器)
function Install-Chocolatey {
    if (-not (Test-CommandExists choco)) {
        Write-ColorOutput Yellow "→ 安装 Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
}

# 安装 Pandoc
function Install-Pandoc {
    if (-not (Test-CommandExists pandoc)) {
        Write-ColorOutput Yellow "→ 安装 Pandoc..."
        choco install pandoc -y
        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        $version = pandoc --version | Select-Object -First 1
        Write-ColorOutput Green "✓ Pandoc 已安装 ($version)"
    }
}

# 安装 Node.js
function Install-NodeJS {
    if (-not (Test-CommandExists node)) {
        Write-ColorOutput Yellow "→ 安装 Node.js..."
        choco install nodejs -y
        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        $version = node --version
        Write-ColorOutput Green "✓ Node.js 已安装 ($version)"
    }
}

# 安装 mermaid-cli
function Install-MermaidCLI {
    if (-not (Test-CommandExists mmdc)) {
        Write-ColorOutput Yellow "→ 安装 mermaid-cli..."
        npm install -g @mermaid-js/mermaid-cli
    } else {
        $version = mmdc --version
        Write-ColorOutput Green "✓ mermaid-cli 已安装 ($version)"
    }
}

# 创建全局命令
function Install-GlobalCLI {
    Write-ColorOutput Yellow "→ 安装全局 CLI 命令..."
    
    # 创建 bin 目录
    $binDir = Join-Path $SCRIPT_DIR "bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir | Out-Null
    }
    
    # 创建 Windows 批处理文件
    $md2docxBat = Join-Path $binDir "md2docx.bat"
    @"
@echo off
REM Markdown to DOCX 全局命令

set INSTALL_DIR=$SCRIPT_DIR
set CONVERT_SCRIPT=%INSTALL_DIR%\scripts\convert.sh

REM 使用 Git Bash 或 WSL 运行脚本
where bash >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    bash "%CONVERT_SCRIPT%" %*
) else (
    echo 错误: 未找到 bash
    echo 请安装 Git for Windows 或 WSL
    exit /b 1
)
"@ | Out-File -FilePath $md2docxBat -Encoding ASCII
    
    # 创建 PowerShell 脚本
    $md2docxPs1 = Join-Path $binDir "md2docx.ps1"
    @"
# Markdown to DOCX PowerShell 包装器
`$INSTALL_DIR = "$SCRIPT_DIR"
`$CONVERT_SCRIPT = Join-Path `$INSTALL_DIR "scripts\convert.sh"

if (Get-Command bash -ErrorAction SilentlyContinue) {
    & bash `$CONVERT_SCRIPT @args
} else {
    Write-Error "未找到 bash,请安装 Git for Windows 或 WSL"
    exit 1
}
"@ | Out-File -FilePath $md2docxPs1 -Encoding UTF8
    
    # 添加到 PATH
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$binDir*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
        Write-ColorOutput Green "✓ 已添加到 PATH"
        Write-ColorOutput Yellow "  请重启终端以使用 md2docx 命令"
    }
}

# 创建配置文件
function Create-Config {
    Write-ColorOutput Yellow "→ 创建配置文件..."
    
    $configFile = Join-Path $SCRIPT_DIR ".md2docx.conf"
    @"
# Markdown to DOCX 配置文件
# 安装路径
INSTALL_DIR="$SCRIPT_DIR"

# Pandoc 配置
PANDOC_HIGHLIGHT_STYLE="github"
PANDOC_MATH_FORMAT="mathml"

# Mermaid 配置
MERMAID_THEME="default"
MERMAID_BACKGROUND="transparent"
MERMAID_WIDTH="1200"
MERMAID_HEIGHT="800"

# 输出配置
DEFAULT_OUTPUT_DIR="."
USE_CUSTOM_TEMPLATE="true"
"@ | Out-File -FilePath $configFile -Encoding UTF8
    
    # 复制到用户目录
    $userConfig = Join-Path $env:USERPROFILE ".md2docx.conf"
    Copy-Item $configFile $userConfig -Force
    
    Write-ColorOutput Green "✓ 配置文件已创建"
}

# 创建默认模板
function Create-DefaultTemplate {
    Write-ColorOutput Yellow "→ 创建默认模板..."
    $createTemplateScript = Join-Path $SCRIPT_DIR "scripts\create_template.sh"
    
    if (Test-CommandExists bash) {
        & bash $createTemplateScript
    } else {
        Write-ColorOutput Yellow "  跳过模板创建 (需要 bash)"
    }
}

# 主安装流程
function Main {
    Write-ColorOutput Blue "步骤 1/7: 检查包管理器"
    Install-Chocolatey
    Write-Output ""
    
    Write-ColorOutput Blue "步骤 2/7: 安装 Pandoc"
    Install-Pandoc
    Write-Output ""
    
    Write-ColorOutput Blue "步骤 3/7: 安装 Node.js"
    Install-NodeJS
    Write-Output ""
    
    Write-ColorOutput Blue "步骤 4/7: 安装 mermaid-cli"
    Install-MermaidCLI
    Write-Output ""
    
    Write-ColorOutput Blue "步骤 5/7: 安装全局 CLI"
    Install-GlobalCLI
    Write-Output ""
    
    Write-ColorOutput Blue "步骤 6/7: 创建配置文件"
    Create-Config
    Write-Output ""
    
    Write-ColorOutput Blue "步骤 7/7: 创建默认模板"
    Create-DefaultTemplate
    Write-Output ""
    
    Write-ColorOutput Green "======================================"
    Write-ColorOutput Green "  ✓ 安装完成!"
    Write-ColorOutput Green "======================================"
    Write-Output ""
    Write-ColorOutput Blue "使用方法:"
    Write-Output ""
    Write-ColorOutput Green "  命令行:"
    Write-Output "    md2docx document.md"
    Write-Output "    md2docx input.md output.docx"
    Write-Output ""
    Write-ColorOutput Green "  PowerShell:"
    Write-Output "    .\bin\md2docx.ps1 document.md"
    Write-Output ""
    Write-ColorOutput Green "  批量转换:"
    Write-Output "    bash $SCRIPT_DIR\scripts\batch_convert.sh *.md"
    Write-Output ""
    Write-ColorOutput Yellow "注意: 请重启终端以使用 md2docx 命令"
    Write-Output ""
    Write-ColorOutput Yellow "提示: 建议安装 Git for Windows 以获得完整功能"
    Write-Output "      下载地址: https://git-scm.com/download/win"
}

# 运行主程序
try {
    Main
} catch {
    Write-ColorOutput Red "安装过程中出现错误:"
    Write-ColorOutput Red $_.Exception.Message
    exit 1
}

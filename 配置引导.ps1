#Requires -Version 5.1
<#
.SYNOPSIS
  MotrixNext 直连 - 配置引导脚本
.DESCRIPTION
  交互式:输入要绕走的代理端口 → 自动部署切换脚本 → 初始化为直连。
  用户双击「配置引导.bat」即调用本脚本。
#>

$ErrorActionPreference = 'Stop'
$script:confirmedPort = $null

function Write-T($msg) { Write-Host $msg -ForegroundColor White }
function Write-Ok($m)  { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err($m) { Write-Host "[X] $m" -ForegroundColor Red }
function Write-H($m)   { Write-Host $m -ForegroundColor Cyan }

# ---------- 0. 欢迎横幅 ----------
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "    Motrix Next 直连 - 自动配置向导            " -ForegroundColor Cyan
Write-Host "    让下载流量绕开你的代理(省流量)            " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 1. 前置检查:Motrix 是否安装 ----------
Write-H "[1/5] 检测 Motrix Next ..."
$cfgPath = Join-Path $env:APPDATA 'com.motrix.next\config.json'
if (-not (Test-Path $cfgPath)) {
    Write-Err "未检测到 Motrix Next 配置文件:"
    Write-Err "  $cfgPath"
    Write-Err ""
    Write-Err "请先安装并至少运行一次 Motrix Next,再运行本向导。"
    Read-Host "回车退出"
    exit 1
}
$cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$rpcPort = if ($cfg.preferences.rpcListenPort) { $cfg.preferences.rpcListenPort } else { 16800 }
Write-Ok "已检测到 Motrix Next"
Write-Host "       配置文件: $cfgPath" -ForegroundColor DarkGray
Write-Host "       aria2 RPC 端口: $rpcPort" -ForegroundColor DarkGray

# ---------- 2. 输入代理端口 ----------
Write-Host ""
Write-H "[2/5] 输入要绕走的代理端口"
Write-T "请输入你的代理软件监听端口(常见:Clash 用 7890,V2Ray 用 10809)。"
Write-T "Motrix 下载时若被切换为「走代理」,会通过此端口转发。"
Write-T "默认 7890,直接回车即用 7890。"
$portOk = $false
$attempts = 0
while (-not $portOk -and $attempts -lt 5) {
    $attempts++
    $input = Read-Host "代理端口 [7890]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = '7890' }
    $v = 0
    if ([int]::TryParse($input.Trim(), [ref]$v) -and $v -ge 1 -and $v -le 65535) {
        $script:confirmedPort = $v
        $portOk = $true
    } else {
        Write-Warn "「$input」不是有效端口(1-65535),请重新输入。"
    }
}
if (-not $portOk) {
    Write-Err "多次输入无效,已退出。请重新运行向导。"
    Read-Host "回车退出"
    exit 1
}
Write-Ok "代理端口设为:$($script:confirmedPort)"

# ---------- 3. 探测端口是否在线(仅提示,不阻断)----------
Write-Host ""
Write-H "[3/5] 探测代理端口连通性 ..."
$proxyUp = $false
try {
    $t = Test-NetConnection -ComputerName 127.0.0.1 -Port $script:confirmedPort -WarningAction SilentlyContinue
    $proxyUp = $t.TcpTestSucceeded
} catch { $proxyUp = $false }
if ($proxyUp) {
    Write-Ok "端口 $($script:confirmedPort) 正在监听(代理软件在线)"
} else {
    Write-Warn "端口 $($script:confirmedPort) 当前未监听 —— 不影响直连配置。"
    Write-Host "       (等你想用「走代理」模式时,再开代理软件即可)" -ForegroundColor DarkGray
}

# ---------- 4. 部署文件 ----------
Write-Host ""
Write-H "[4/5] 部署切换脚本 ..."
$destDir = Join-Path $env:LOCALAPPDATA 'MotrixProxy'
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

# 4.1 复制 ps1(模板目录就在本脚本同级的 模板\ 下)
$srcPs1 = Join-Path $PSScriptRoot '模板\motrix-proxy.ps1'
if (-not (Test-Path $srcPs1)) {
    Write-Err "找不到模板脚本: $srcPs1"
    Write-Err "分发包不完整,请重新获取。"
    Read-Host "回车退出"
    exit 1
}
$dstPs1 = Join-Path $destDir 'motrix-proxy.ps1'

# 保留 BOM 的二进制复制(避免 Out-File 丢 BOM)
$bytes = [System.IO.File]::ReadAllBytes($srcPs1)
[System.IO.File]::WriteAllBytes($dstPs1, $bytes)
# 校验 BOM
$head = $bytes[0..2] | ForEach-Object { [int]$_ }
if ($head[0] -ne 0xEF -or $head[1] -ne 0xBB -or $head[2] -ne 0xBF) {
    Write-Warn "模板 ps1 缺少 UTF-8 BOM,自动补上 ..."
    $bom = [byte[]](0xEF,0xBB,0xBF)
    $body = [System.IO.File]::ReadAllBytes($dstPs1)
    $all = New-Object byte[] ($bom.Length + $body.Length)
    [Array]::Copy($bom, 0, $all, 0, $bom.Length)
    [Array]::Copy($body, 0, $all, $bom.Length, $body.Length)
    [System.IO.File]::WriteAllBytes($dstPs1, $all)
}
Write-Ok "已部署: $dstPs1"

# 4.2 写入 port.txt
$portFile = Join-Path $destDir 'port.txt'
"$($script:confirmedPort)" | Out-File -FilePath $portFile -Encoding UTF8
Write-Ok "已写入代理端口: $portFile ($($script:confirmedPort))"

# 4.3 询问是否部署双击 bat
Write-Host ""
Write-T "是否在桌面创建「Motrix直连」和「Motrix走代理」快捷脚本?"
$deployBat = Read-Host "在桌面创建? [Y/n]"
if ([string]::IsNullOrWhiteSpace($deployBat) -or $deployBat.Trim().ToUpper() -eq 'Y') {
    $desktop = [Environment]::GetFolderPath('Desktop')

    $directBat = Join-Path $desktop 'Motrix直连.bat'
    $batDirect = @"
@echo off
chcp 65001 >nul
title Motrix 直连(不走代理)
color 0A
powershell -NoProfile -ExecutionPolicy Bypass -File "$destDir\motrix-proxy.ps1" -Mode direct
echo.
pause
"@
    [System.IO.File]::WriteAllText($directBat, $batDirect, [System.Text.Encoding]::GetEncoding('gb2312'))

    $proxyBat = Join-Path $desktop 'Motrix走代理.bat'
    $batProxy = @"
@echo off
chcp 65001 >nul
title Motrix 走代理(端口 $($script:confirmedPort))
color 0E
powershell -NoProfile -ExecutionPolicy Bypass -File "$destDir\motrix-proxy.ps1" -Mode proxy
echo.
pause
"@
    [System.IO.File]::WriteAllText($proxyBat, $batProxy, [System.Text.Encoding]::GetEncoding('gb2312'))

    Write-Ok "已在桌面创建: $directBat"
    Write-Ok "已在桌面创建: $proxyBat"
} else {
    Write-Warn "跳过桌面脚本创建。"
    Write-Host "       (切换脚本已就位,如需手动创建 bat 可参考 README)" -ForegroundColor DarkGray
}

# ---------- 5. 初始化为直连 ----------
Write-Host ""
Write-H "[5/5] 初始化为直连状态(立即生效)..."
& powershell -NoProfile -ExecutionPolicy Bypass -File $dstPs1 -Mode direct | Out-Host

# ---------- 完成 ----------
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host " 配置完成!                                  " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-T "当前状态:Motrix 直连(不走代理,省流量)"
Write-Host ""
Write-T "日常使用:"
Write-Host "  • 桌面「Motrix直连.bat」  = 直连(默认,保持这个)" -ForegroundColor White
Write-Host "  • 桌面「Motrix走代理.bat」= 临时走代理下载资源" -ForegroundColor White
Write-Host ""
Write-T "代理端口: $($script:confirmedPort)(改端口重跑本向导,或编辑 %LOCALAPPDATA%\MotrixProxy\port.txt)"
Write-Host ""

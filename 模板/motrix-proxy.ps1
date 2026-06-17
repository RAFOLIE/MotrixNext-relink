#Requires -Version 5.1
<#
.SYNOPSIS
  Motrix Next 代理一键切换 - 共享脚本
.DESCRIPTION
  代理端口从 port.txt 动态读取,不硬编码。查找顺序:
    1) 脚本同目录的 port.txt
    2) %LOCALAPPDATA%\MotrixProxy\port.txt(部署后的位置)
  都找不到则默认 7890。
.PARAMETER Mode
  proxy  = 走代理(下载墙外资源)
  direct = 直连(不走代理,省流量,默认)
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('proxy', 'direct')]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'

# ---------- 从 port.txt 读代理端口 ----------
function Get-ProxyPort {
    $candidates = @(
        (Join-Path $PSScriptRoot 'port.txt'),
        (Join-Path $env:LOCALAPPDATA 'MotrixProxy\port.txt')
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) {
            $raw = (Get-Content $p -Raw -ErrorAction SilentlyContinue).Trim()
            $v = 0
            if ([int]::TryParse($raw, [ref]$v) -and $v -gt 0 -and $v -le 65535) {
                return $v
            }
        }
    }
    return 7890
}
$ProxyPort = Get-ProxyPort
$ProxyUrl  = "http://127.0.0.1:$ProxyPort"

function Write-Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[X] $msg" -ForegroundColor Red }

Write-Host ""
if ($Mode -eq 'proxy') {
    Write-Host "=== Motrix 走代理(端口 $ProxyPort)===" -ForegroundColor Cyan
} else {
    Write-Host "=== Motrix 直连(不走代理)===" -ForegroundColor Cyan
}
Write-Host ""

# ---------- 1. 读取 + 修改 config.json ----------
$cfgPath = Join-Path $env:APPDATA 'com.motrix.next\config.json'
if (-not (Test-Path $cfgPath)) {
    Write-Err "找不到 config.json: $cfgPath"
    Write-Err "请确认 Motrix Next 已安装并至少运行过一次。"
    Read-Host "回车退出"
    exit 1
}

try {
    $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Mode -eq 'proxy') {
        $cfg.preferences.proxy.mode     = 'http'
        $cfg.preferences.proxy.server   = $ProxyUrl
    } else {
        $cfg.preferences.proxy.mode     = 'direct'
        $cfg.preferences.proxy.server   = ''
    }
    $cfg.preferences.proxy.username = ''
    $cfg.preferences.proxy.password = ''

    ($cfg | ConvertTo-Json -Depth 100) | Out-File -FilePath $cfgPath -Encoding UTF8
    if ($Mode -eq 'proxy') {
        Write-Ok "config.json 已写入: mode=http, server=$ProxyUrl"
    } else {
        Write-Ok "config.json 已写入: mode=direct, server=(空)"
    }
} catch {
    Write-Err "写 config.json 失败: $($_.Exception.Message)"
    Read-Host "回车退出"
    exit 1
}

# ---------- 2. 动态读 RPC 连接信息 ----------
$secret = $cfg.preferences.rpcSecret
$port   = if ($cfg.preferences.rpcListenPort) { [int]$cfg.preferences.rpcListenPort } else { 16800 }
$rpcUrl = "http://127.0.0.1:$port/jsonrpc"

# ---------- 3. 走代理模式:先探测代理端口是否在线 ----------
if ($Mode -eq 'proxy') {
    Write-Host ""
    Write-Host "检查代理端口 127.0.0.1:$ProxyPort 是否在监听..." -ForegroundColor DarkGray
    $proxyUp = $false
    try {
        $t = Test-NetConnection -ComputerName 127.0.0.1 -Port $ProxyPort -WarningAction SilentlyContinue
        $proxyUp = $t.TcpTestSucceeded
    } catch { $proxyUp = $false }
    if (-not $proxyUp) {
        Write-Warn "127.0.0.1:$ProxyPort 未监听,代理软件(Clash/V2Ray 等)可能没开。已写入配置,但下载会失败"
    } else {
        Write-Ok "代理端口 $ProxyPort 在线"
    }
}

# ---------- 4. 推送到 aria2(即时生效)----------
Write-Host ""
Write-Host "正在通知 aria2 引擎(即时生效)..." -ForegroundColor DarkGray
$pushed = $false
try {
    if ($Mode -eq 'proxy') {
        $opts = [ordered]@{
            'all-proxy'=$ProxyUrl; 'http-proxy'=$ProxyUrl; 'https-proxy'=$ProxyUrl;
            'all-proxy-user'=''; 'all-proxy-passwd'='';
            'http-proxy-user'=''; 'http-proxy-passwd'='';
            'https-proxy-user'=''; 'https-proxy-passwd'=''
        }
    } else {
        $opts = [ordered]@{
            'all-proxy'=''; 'http-proxy'=''; 'https-proxy'='';
            'all-proxy-user'=''; 'all-proxy-passwd'='';
            'http-proxy-user'=''; 'http-proxy-passwd'='';
            'https-proxy-user'=''; 'https-proxy-passwd'='';
            'no-proxy'='127.0.0.1,localhost,::1'
        }
    }
    $body = @{ jsonrpc='2.0'; id="motrix-$Mode"; method='aria2.changeGlobalOption'; params=@("token:$secret", $opts) } | ConvertTo-Json -Compress -Depth 10
    Invoke-RestMethod -Uri $rpcUrl -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 5 | Out-Null
    $pushed = $true
} catch {
    Write-Warn "aria2 引擎未运行或 RPC 不通,已写入配置,下次启动 Motrix 后生效"
}

# ---------- 5. 回读验证 ----------
if ($pushed) {
    Start-Sleep -Milliseconds 200
    try {
        $q = @{ jsonrpc='2.0'; id='verify'; method='aria2.getGlobalOption'; params=@("token:$secret") } | ConvertTo-Json -Compress
        $r = Invoke-RestMethod -Uri $rpcUrl -Method Post -Body $q -ContentType 'application/json' -TimeoutSec 5
        Write-Host ""
        Write-Host ("当前 aria2 all-proxy = [{0}]" -f $r.result.'all-proxy') -ForegroundColor Green
        Write-Host ("当前 aria2 http-proxy = [{0}]" -f $r.result.'http-proxy') -ForegroundColor Green
    } catch {
        Write-Warn "切换已下发,但回读验证失败(不影响使用)"
    }
}

# ---------- 6. 结果横幅 ----------
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($Mode -eq 'proxy') {
    Write-Host " Motrix 已切换为走代理(端口 $ProxyPort)      " -ForegroundColor Yellow
    Write-Host " 下载墙外资源时使用,完成后请切回直连   " -ForegroundColor Yellow
} else {
    Write-Host " Motrix 已切换为直连,不走代理          " -ForegroundColor Green
    Write-Host " 下载流量不再消耗你的代理额度           " -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

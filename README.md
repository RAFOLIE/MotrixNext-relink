# MotrixNext-relink

> 🌐 **中文** | [English](#english-below)

一个让 [Motrix Next](https://github.com/agalwood/Motrix) 下载器**默认走直连、绕开你的代理端口**的小工具,需要下墙外资源时一键切到走代理,下完切回。**省你的代理流量额度。**

```
双击「配置引导.bat」→ 输入代理端口 → 自动配好 → 完事
```

---

## 它解决什么问题

装了代理软件(Clash / V2Ray / Surge 等)后,Motrix Next 内置的 aria2 引擎可能把**所有下载流量**都走代理,白白烧掉代理流量额度——尤其是下大文件、BT、迅雷链时。

MotrixNext-relink 让你:
- 🟢 **默认直连**(日常下载不耗代理流量)
- 🟡 **一键切走代理**(下墙外资源时)
- 🟢 **一键切回直连**(下完恢复)

切换**即时生效**(通过 aria2 JSON-RPC),无需重启 Motrix;同时持久化到配置,重启 Motrix 状态不变。

---

## 快速开始

### 安装
1. 从 [Releases](../../releases/latest) 下载 `MotrixNext-relink-v1.0.0.zip`
2. 解压到任意位置
3. 双击 `配置引导.bat`
4. 按提示输入你的代理端口(常见:Clash `7890`、V2Ray `10809`、Surge `6152`),直接回车默认 7890
5. 回车确认在桌面创建两个切换脚本
6. 完成 —— Motrix 已自动设为直连

### 日常使用(桌面两个脚本)
| 脚本 | 作用 | 什么时候用 |
|---|---|---|
| `Motrix直连.bat` 🟢 | **默认保持**,不走代理 | 日常下载(省代理流量) |
| `Motrix走代理.bat` 🟡 | 临时走代理 | 下墙外资源(下完切回) |

### 换端口 / 重装 / 换电脑
重新双击 `配置引导.bat`,输入新端口即可。会自动重新部署,无需手动改任何文件。

---

## 工作原理

### 切换机制(双写:即时 + 持久)
1. **改 config.json**(`proxy.mode` / `proxy.server`):持久化,重启 Motrix 后状态不变
2. **调 aria2 JSON-RPC**(`aria2.changeGlobalOption`):即时生效,进行中的下载任务也立即切换

### 端口外置设计
代理端口存在 `%LOCALAPPDATA%\MotrixProxy\port.txt`(纯数字),引导脚本负责写入。换端口直接编辑这个文件,或重跑引导。

### aria2 推送的值
- **直连**:`all-proxy=""`, `http-proxy=""`, `https-proxy=""`, `no-proxy="127.0.0.1,localhost,::1"`
  - 空串强制覆盖,防止 aria2 回退读 `HTTP_PROXY` 等环境变量导致泄漏
- **走代理**:`all-proxy=http://127.0.0.1:<端口>`, `http-proxy=同`, `https-proxy=同`

### 覆盖范围
切换同时覆盖三方面:`proxy.scope = ["download", "update-app", "update-trackers"]`
- 下载流量
- 应用更新检查
- BT trackers 列表同步

### 为什么在 Motrix 侧控制,而不是代理软件侧
代理软件(如 Clash Verge)常用 **System Proxy 模式**(系统代理),该模式**无法按进程名放行**(PROCESS-NAME 规则需要 TUN 模式才生效)。所以必须在 Motrix(aria2)这一侧切换 `all-proxy`,这是最干净可靠的做法。

---

## 文件清单

### 分发包内容
```
MotrixNext-relink\
├── README.md              本文件
├── LICENSE                MIT 协议
├── CHANGELOG.md           版本变更
├── 配置引导.bat            【用户入口】双击这个
├── 配置引导.ps1            引导逻辑
├── 模板\
│   ├── motrix-proxy.ps1   切换逻辑(部署时复制到 AppData)
│   ├── Motrix直连.bat        桌面脚本模板
│   └── Motrix走代理.bat      桌面脚本模板
└── 设置快照\
    └── aria2.conf         Motrix 原厂 aria2 配置(参考)
```

### 引导脚本部署后,文件落在哪
| 文件 | 路径 | 作用 |
|---|---|---|
| 切换逻辑 | `%LOCALAPPDATA%\MotrixProxy\motrix-proxy.ps1` | 真正的切换代码 |
| 端口配置 | `%LOCALAPPDATA%\MotrixProxy\port.txt` | 记录代理端口 |
| 桌面脚本 | 桌面 `\Motrix直连.bat` / `Motrix走代理.bat` | 双击入口 |

---

## 验证当前状态(只读,不改动)

```powershell
$c = Get-Content "$env:APPDATA\com.motrix.next\config.json" -Raw | ConvertFrom-Json
$secret = $c.preferences.rpcSecret
$port = $c.preferences.rpcListenPort
$q = @{jsonrpc='2.0'; id='chk'; method='aria2.getGlobalOption'; params=@("token:$secret")} | ConvertTo-Json -Compress
$r = Invoke-RestMethod -Uri "http://127.0.0.1:$port/jsonrpc" -Method Post -Body $q -ContentType 'application/json' -TimeoutSec 5
Write-Host "config.json mode = $($c.preferences.proxy.mode)"
Write-Host "aria2 all-proxy  = [$($r.result.'all-proxy')]"
```
- `mode = direct` 且 `all-proxy = []`(空)= **直连**(不走代理)
- `mode = http` 且 `all-proxy = [http://127.0.0.1:<端口>/]` = **走代理**

---

## 🔒 隐私与安全

- **本工具不会上传任何信息**,完全本地运行
- 运行时动态读取你本地 Motrix 的 RPC secret,**不存储、不外传**
- 不修改代理软件任何配置
- 不安装任何系统服务、不写注册表、不设环境变量
- 所有改动仅限于 `%LOCALAPPDATA%\MotrixProxy\` 和 Motrix 的 config.json

> ⚠️ **如果你之前用过含个人配置快照的版本**:建议在 Motrix Next 设置里重新生成一次 RPC secret(轮换),以防泄露。

---

## FAQ

**Q: 支持 Clash for Windows / V2RayN / Surge / 其它代理吗?**
A: 支持任何提供本地 HTTP 代理端口的软件。引导时输入对应端口即可。

**Q: 切换后没生效?**
A: 确认 Motrix Next 正在运行(引导脚本会检测 aria2 RPC 是否在线)。如果 Motrix 没开,配置已写入,下次启动会生效。

**Q: 双击「走代理」后下载失败?**
A: 脚本会探测端口,如果代理软件没开会黄色警告。先把代理软件打开再切。

**Q: 走代理时回显 `all-proxy = [http://127.0.0.1:7890/]`(带尾斜杠)是 bug 吗?**
A: 不是。这是 aria2 对 URL 的规范化结果,不影响功能。

**Q: Clash 开了 TUN 模式,本工具还有效吗?**
A: 有效。本工具在 Motrix 侧控制 `all-proxy`,不受 Clash 模式影响。但 TUN 模式下你可能想额外用 PROCESS-NAME 规则做兜底。

**Q: Motrix 升级后脚本失效?**
A: 不会。RPC secret 是运行时动态读取的。如果升级重置了 proxy 配置,双击一次切换脚本即可纠正。

**Q: 换电脑怎么迁移?**
A: 把整个文件夹拷过去,双击 `配置引导.bat`,输入新端口即可。

---

## 系统要求

- Windows 10 / 11
- PowerShell 5.1+(系统自带)
- [Motrix Next](https://github.com/agalwood/Motrix) 已安装并至少运行过一次
- 任意本地 HTTP 代理软件(Clash / V2Ray / Surge 等)

---

## 已知限制

1. **仅支持 HTTP 代理端口**:本工具推送的是 `http-proxy` / `all-proxy`。纯 SOCKS 端口请先用代理软件的混合端口(mixed-port)。
2. **System Proxy 模式按进程放行无效**:这是代理软件的限制(需 TUN),所以本工具选择在 Motrix 侧控制。
3. **含中文的 ps1 文件需 UTF-8 BOM**:PowerShell 5.1 无 BOM 会解析失败。引导脚本部署时会自动校验并补 BOM。

---

## 🤝 参与贡献

欢迎提 Issue / PR。开发注意:
- 任何重写含中文的 ps1,确保以 UTF-8 BOM(`EF BB BF`)开头
- 改完用「验证当前状态」的命令测一遍 proxy/direct 循环
- 不要在代码里硬编码端口或 secret(应从 port.txt / config.json 动态读)

---

## 📄 License

[MIT](LICENSE) © 2026 RAFOLIE

---

# English

# MotrixNext-relink (English)

A tiny tool that makes [Motrix Next](https://github.com/agalwood/Motrix) **download directly by default, bypassing your proxy port** — so you don't burn through your proxy data quota. Switch to proxy mode with one click when you need to grab geo-restricted content, then switch back.

```
Double-click "配置引导.bat" (setup guide) → enter your proxy port → done
```

## What it solves

With a proxy client running (Clash / V2Ray / Surge), Motrix Next's bundled aria2 engine may route **all download traffic** through the proxy — wasting your proxy quota, especially on large files, torrents, and thunder links.

MotrixNext-relink lets you:
- 🟢 **Default: direct** (daily downloads don't use proxy quota)
- 🟡 **One-click → proxy** (for geo-restricted content)
- 🟢 **One-click → back to direct**

Switching is **instant** (via aria2 JSON-RPC, no Motrix restart) and **persisted** (survives Motrix restart).

## Quick start
1. Download `MotrixNext-relink-v1.0.0.zip` from [Releases](../../releases/latest)
2. Extract anywhere
3. Double-click `配置引导.bat` (the setup guide)
4. Enter your proxy port (Clash `7890`, V2Ray `10809`, Surge `6152`; default 7890)
5. Confirm desktop shortcuts creation
6. Done — Motrix is now set to direct

## Why control on the Motrix side, not the proxy side
Proxy clients (e.g. Clash Verge) in **System Proxy mode cannot do per-process bypass** (PROCESS-NAME rules require TUN mode). So the clean, reliable fix is toggling `all-proxy` inside Motrix's aria2 engine via its JSON-RPC.

## Privacy
- 100% local. **Nothing is uploaded.**
- Reads Motrix's RPC secret at runtime — never stored or transmitted.
- No system services, no registry writes, no env vars.

## Requirements
- Windows 10/11 with PowerShell 5.1+
- [Motrix Next](https://github.com/agalwood/Motrix) installed & run at least once
- Any local HTTP proxy software

## License
[MIT](LICENSE) © 2026 RAFOLIE

# Changelog

本项目所有重要变更都记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2026-06-17

首个公开发布版本。

### 新增
- 🎯 **交互式配置引导**:双击 `配置引导.bat`,输入代理端口即可,5 步全自动完成部署
- ⚡ **即时切换**:通过 aria2 JSON-RPC(`aria2.changeGlobalOption`)实时切换 `all-proxy`,无需重启 Motrix,进行中的下载任务也立即生效
- 💾 **双写持久化**:同时改 config.json 和 aria2 运行时状态,重启 Motrix 后配置保持
- 🔌 **端口外置设计**:代理端口存在 `port.txt`,不再硬编码 7890,支持 Clash/V2Ray/Surge 任意端口
- 🛡️ **BOM 自动校验**:引导脚本部署 ps1 时检测并补全 UTF-8 BOM,规避 PowerShell 5.1 中文乱码坑
- 🔍 **连通性探测**:走代理模式前自动探测代理端口是否在线,避免静默失败
- ✅ **切换后回读验证**:切换完成立即回读 aria2 全局选项,确认实际生效
- 📋 **全范围覆盖**:切换同时覆盖下载流量、应用更新检查、BT trackers 同步

### 安全
- 完全本地运行,不上传任何信息
- RPC secret 运行时动态读取,不存储不外传
- 直连时显式推送空串,防止 aria2 回退读环境变量导致泄漏

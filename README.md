# Codex Usage

一个 macOS 状态栏小工具，用来显示 Codex 的本地用量额度。

当前版本优先读取 Codex 本地 session 日志，不依赖 ChatGPT 用量网页是否打开或刷新。

```text
5h 43% 01:22
1w 3%  7月7日
```

## 功能

- 显示 5 小时额度的剩余百分比和重置时间。
- 显示周额度的剩余百分比和重置日期。
- 从 `~/.codex/sessions/**/*.jsonl` 读取 Codex 本地用量数据。
- Codex 正在运行时，状态栏每 5 秒刷新一次显示。
- Codex 未运行时显示 `Paused`。
- 解析后的轻量缓存写到 `~/Library/Application Support/CodexUsageMenubar/usage.json`。
- 仓库里仍保留早期 Chrome Native Messaging 方案，但当前状态栏正常显示不再依赖 Chrome。

## 环境要求

- macOS 14 或更新版本
- Xcode / Swift toolchain，支持 Swift Package Manager
- Node.js，仅用于运行 JavaScript 测试
- Codex 桌面端会在 `~/.codex/sessions` 写入本地 session 日志

## 构建和启动

构建状态栏 app：

```bash
scripts/build-app.sh
```

启动：

```bash
open "dist/Codex Usage.app"
```

退出当前运行的状态栏 app：

```bash
pkill -f "/Users/star/myapp/codex-usage/dist/Codex Usage.app/Contents/MacOS/Codex Usage"
```

## 显示逻辑

app 会扫描最近的 Codex session JSONL 文件，查找最新的 `token_count` 事件，并读取：

- `rate_limits.primary`
- `rate_limits.secondary`

这些字段里的值是 `used_percent`，所以状态栏显示的剩余额度是：

```text
remaining = 100 - used_percent
```

5 小时额度的重置时间显示为本地时间 `HH:mm`。

周额度的重置日期显示为 `M月d日`。

如果找不到本地 session 用量数据，会回退显示上一次解析后的缓存。Codex 未运行时显示 `Paused`。

## 菜单项

- `Refresh Now`：立即重新读取本地 Codex session 日志。
- `Open ChatGPT Usage Page`：打开 ChatGPT Codex 用量页面，方便人工查看。
- `Quit`：退出状态栏 app。

## 测试

运行全部测试：

```bash
npm test
```

只运行 Swift 测试：

```bash
swift test
```

只运行 JavaScript 测试：

```bash
npm run test:js
```

## 可选的 Chrome 伴随扩展

仓库里仍保留 Chrome extension 和 Native Messaging host：

- `extension/`
- `Sources/CodexUsageNativeHost/`
- `scripts/register-native-host.sh`

它们属于早期网页用量来源方案。当前状态栏显示已经改成本地 session 优先，正常使用不需要安装扩展。

如果要继续调试扩展，可以注册 native host：

```bash
scripts/register-native-host.sh <chrome-extension-id>
```

## 项目结构

- `Sources/CodexUsageMenubar/`：AppKit 状态栏 app。
- `Sources/CodexUsageShared/`：共享模型、本地 session 读取器、格式化、缓存、Native Messaging 编解码。
- `Sources/CodexUsageNativeHostCore/`：Native Messaging host 的请求处理逻辑。
- `Sources/CodexUsageNativeHost/`：Chrome Native Messaging host 可执行入口。
- `Tests/`：Swift 单元测试。
- `extension/`：可选 Chrome 扩展和 JavaScript 测试。
- `scripts/`：构建、注册和 smoke test 脚本。
- `docs/`：设计记录和早期手动验证文档。

## 隐私

状态栏 app 只保存解析后的额度字段、重置时间、来源元数据和状态。它不保存 cookie、请求头、ChatGPT 原始响应，也不读取或保存 Codex 对话内容。


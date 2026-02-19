# CubeTwenty

<p align="center">
  <img src="CubeTwenty/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" alt="CubeTwenty icon">
</p>

<p align="center">
  macOS 菜单栏工具 · 20-20-20 护眼提醒 + 番茄钟
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

---

## 功能

### 🧿 20-20-20 护眼提醒
每隔 20 分钟提醒你看向 20 尺（约 6 米）以外的地方，持续 20 秒，有效缓解视觉疲劳。

- **仅计算屏幕使用时间**：锁屏、熄屏、系统睡眠时自动暂停，唤醒后重置为完整间隔
- 可自定义提醒间隔（5–60 分钟）
- 支持手动立即触发

### 🍅 番茄钟
专注工作，定时休息，内置长休息机制。

- 可自定义专注时长（默认 25 分钟）、短休息（5 分钟）、长休息（15 分钟）
- 每完成 N 个番茄后自动触发长休息（N 可配置，默认 4）
- 今日 / 本周完成数统计（SwiftData 持久化）

### 🔗 两者联动
番茄钟进入休息阶段时，护眼提醒自动暂停；休息结束后自动恢复并重置计时。

### 其他
- 菜单栏常驻，无 Dock 图标，轻量不打扰
- 开机自启（可在设置中关闭）
- 自动更新（Sparkle 2.x）

---

## 系统要求

- **macOS 14 Sonoma** 或更高版本

---

## 安装

前往 [Releases](../../releases) 页面下载最新版本的 `.dmg` 或 `.zip`，拖入应用程序文件夹即可。

> 首次启动时，macOS 可能提示"无法验证开发者"。前往**系统设置 → 隐私与安全性**，点击"仍要打开"即可。

---

## 从源码构建

### 前置条件

- Xcode 15 或更高版本
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
```

### 构建步骤

```bash
# 1. Clone 仓库
git clone https://github.com/<your-username>/CubeTwenty.git
cd CubeTwenty

# 2. 生成 Xcode 项目
xcodegen generate

# 3. 用 Xcode 打开并构建
open CubeTwenty.xcodeproj
```

在 Xcode 中选择目标设备为 **My Mac**，按 `Cmd+R` 运行。

---

## 配置自动更新（Sparkle）

如需发布自己的版本并启用自动更新：

1. 在 Sparkle 包内运行 `./bin/generate_keys` 生成 Ed25519 密钥对
2. 将公钥填入 `CubeTwenty/Info.plist` 的 `SUPublicEDKey` 字段
3. 将 `SUFeedURL` 替换为你托管的 `appcast.xml` 地址
4. 在 `project.yml` 中填入你的 `DEVELOPMENT_TEAM`，通过 Xcode Archive 导出并签名

详细步骤参见 [CLAUDE.md](CLAUDE.md)。

---

## License

[MIT](LICENSE) © 2025 Chaolinhan

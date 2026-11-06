# AGENTS.md

## Project Overview

**Chain** - macOS Finder 右键菜单扩展，提供以下功能：
- 在当前目录打开所选 app（terminal 或 editor）
- 新建 Markdown 文件

## Tech Stack

- **Language**: Swift 5.9+
- **Framework**: SwiftUI (主 App) + FinderSync (Extension)
- **Target**: macOS 14.0+
- **Build Tool**: Xcode 15+

## Project Structure

```
FinderTools/                        # 仓库根目录
├── Chain/                          # 主 App
│   ├── ChainApp.swift              # App 入口、AppDelegate、URL 分发
│   ├── CommandExecutor.swift       # 打开 App、新建笔记、错误弹窗
│   ├── CustomCommandRunner.swift   # 运行自定义命令（有副作用的部分）
│   ├── ShellCommand.swift          # 命令拼接、转义、各终端运行方式（纯函数）
│   ├── SettingsModels.swift        # ObservableObject 状态模型
│   ├── MenuBarViews.swift          # 菜单栏和自定义命令面板
│   ├── ChainMaintenance.swift      # 重新注册 Finder 扩展
│   ├── ChainAppSupport.swift       # 共享类型：ChainSupportedApp、ChainCommandURL、ChainAppCatalog
│   ├── ChainSettings.swift         # 主 App 偏好设置读写，扩展只读（编译进两个 target）
│   ├── Info.plist
│   ├── Entitlements.plist
│   └── Assets.xcassets/
├── ChainExtension/                 # Finder 扩展
│   ├── FinderSync.swift            # 右键菜单构建、URL command 发送
│   ├── TargetDirectoryResolver.swift  # 目标目录解析逻辑
│   ├── Info.plist
│   └── Entitlements.plist
├── Tests/                          # 测试（独立可执行文件，非 XCTest）
│   ├── ChainMenuModelTests.swift
│   ├── ChainMenuContextResolverTests.swift
│   ├── ChainMenuPresentationTests.swift
│   ├── ChainMenuBarRequirementsTests.swift
│   ├── ChainEnglishMenuRequirementsTests.swift
│   └── ChainLaunchAtLoginRequirementsTests.swift
└── Chain.xcodeproj/
```

## Commands

```bash
# 用 Xcode 打开项目
open Chain.xcodeproj

# 命令行构建 (需要 xcodebuild)
xcodebuild -project Chain.xcodeproj -scheme Chain -configuration Debug build

# 如果构建失败在 signing/provisioning profile，允许 Xcode 刷新本机 profile
xcodebuild -project Chain.xcodeproj -scheme Chain -configuration Debug -allowProvisioningUpdates build

# 清理构建
xcodebuild clean -project Chain.xcodeproj
```

## Build & Install（每次构建后必须执行）

### 本机默认方式：本地签名

```bash
scripts/install_local.sh
```

脚本用 `CODE_SIGNING_ALLOWED=NO` 编译，再用 `codesign` 按两份 entitlements 做 ad-hoc 签名并安装，不需要 Apple 账号和描述文件，也不会过期。本机已停用自动修复任务，下面依赖 Xcode 账号的自动修复和手动 `xcodebuild` 安装流程只在改回开发签名时才需要。

不要再加回 App Group：没有描述文件时，macOS 每次启动都会弹“访问其他 App 的数据”。设置存在主 App 的偏好设置（`com.lursetawet.chain`），扩展通过 `temporary-exception.shared-preference.read-only` 只读，所有写入和 nonce 生成都在主 App。

重新构建后 macOS 可能再次询问控制终端的权限。

### 从新 clone 安装并启用自动修复

当用户请求“在这台电脑使用 Chain”“安装并启用自动构建/续期”时，先阅读 `scripts/README.md`。用当前 clone 的实际绝对路径，不要复用作者机器的路径或 LaunchAgent 文件。

1. 检查完整 Xcode：`xcodebuild -version`、`xcode-select -p`。仅安装 Command Line Tools 不足以构建此 App。
2. 检查当前用户在 Xcode 中已登录的 Apple 账号及可用 Development Team。项目中的 `5S8UY3S34L` 是原作者团队，不应假设另一位用户可用。账号尚未登录时请用户在 Xcode → Settings → Accounts 完成登录；不读取或输出账号密码。
3. 运行 `/usr/bin/python3 scripts/install_auto_repair.py --team <本机可用的10位TeamID>`。已明确可用项目默认团队时可省略 `--team`。安装器会先构建、验证、安装 Chain，再编译签名 Chain Auto Build 启动程序，安装当前用户的 LaunchAgent，并保存团队设置供之后自动构建使用。首次安装不要求已有 `/Applications/Chain.app`。
4. 若 Apple 提示 Bundle ID 或 App Group 属于其他团队，按报错为该用户配置可注册的标识符；不要循环重试原作者标识符。主 App、扩展的 Bundle ID 与两份 entitlements 必须保持正确的对应关系，修改主 App Bundle ID 时同步 `Chain/ChainSettings.swift` 的 `suiteName` 和扩展 entitlements 里的只读例外。脚本注册扩展的 ID 读取已安装扩展的 Info.plist。保留 Extension → Main App 的 URL scheme 一致。
5. 完成后验证 `/usr/bin/python3 scripts/chain_auto_repair.py --check`、安装包 `codesign --verify --deep --strict`、主 App 与扩展进程、`pluginkit -m -v -i <已安装扩展的BundleID>`，以及 `launchctl print gui/$(id -u)/com.lursetawet.chain.auto-repair` 的退出状态。确认系统设置中的 **Chain Auto Build** 后台开关和 Finder 扩展开关。未完成实际安装与运行验证前，不称安装成功。

自动任务每次开机成功后只记录一次，后台每 30 分钟检查描述文件，临近过期最多每六小时完成一次构建，过期或失败后重试。移动仓库后要重新运行安装器更新路径。用户请求停用时运行 `/usr/bin/python3 scripts/install_auto_repair.py --uninstall`；此命令保留已安装 Chain。

`/Applications/Chain.app` 是用户实际运行的版本，DerivedData 里的 build 产物不会自动生效。

**重要**：必须先 `rm -rf` 删除旧 app，再复制新版。直接 `cp -R` 到已存在的目录只会 merge 文件，旧二进制不会被替换，导致新代码不生效。

Finder Extension 插件本体嵌在 app bundle 内：`/Applications/Chain.app/Contents/PlugIns/ChainExtension.appex`。删除 `/Applications/Chain.app` 会一起删除旧插件文件；仍然必须 `pkill -x ChainExtension`、`pluginkit -e use ...`、`killall Finder`，因为 macOS 会缓存扩展注册和运行态。

**重启后打不开的常见原因**：旧的 `/Applications/Chain.app` 仍留在磁盘上，或 app/extension 的 development signing profile 已失效。重启后 macOS 会重新验证磁盘上的 app 和 Finder Extension；之前还在内存里的旧进程不能证明重启后仍能打开。

如果出现 `The application "Chain" can't be opened`、`CSSMERR_TP_NOT_TRUSTED`、`Authority=(unavailable)`、或 `No profiles for 'com.lursetawet.chain' were found`，不要改业务代码。先按下面顺序处理：

```bash
# 1. 重新 build，并允许 Xcode 刷新本机 signing/provisioning
xcodebuild -project Chain.xcodeproj -scheme Chain -configuration Debug -allowProvisioningUpdates build

# 2. 验证新 build 的签名
codesign --verify --deep --strict --verbose=4 "$(xcodebuild -project Chain.xcodeproj -scheme Chain -configuration Debug -showBuildSettings 2>/dev/null | awk '$1=="BUILT_PRODUCTS_DIR"{print $3}')/Chain.app"

# 3. 必须删除旧安装包，再复制新版
pkill -x Chain; pkill -x ChainExtension
BUILD_DIR=$(xcodebuild -project Chain.xcodeproj -scheme Chain -configuration Debug -showBuildSettings 2>/dev/null | awk '$1=="BUILT_PRODUCTS_DIR"{print $3}')
rm -rf /Applications/Chain.app
cp -R "$BUILD_DIR/Chain.app" /Applications/Chain.app

# 4. 启动并重新注册 Finder Extension
open /Applications/Chain.app
sleep 1 && pluginkit -e use -i com.lursetawet.chain.ChainExtension && killall Finder

# 5. 安装后验证
codesign --verify --deep --strict --verbose=4 /Applications/Chain.app
pgrep -fl Chain
pluginkit -m -i com.lursetawet.chain.ChainExtension
```

```bash
# 1. 关闭旧进程
pkill -x Chain; pkill -x ChainExtension

# 2. 删除旧版（必须），再复制新版
BUILD_DIR=$(xcodebuild -project Chain.xcodeproj -scheme Chain -configuration Debug -showBuildSettings 2>/dev/null | awk '$1=="BUILT_PRODUCTS_DIR"{print $3}')
rm -rf /Applications/Chain.app
cp -R "$BUILD_DIR/Chain.app" /Applications/Chain.app

# 3. 重新启动 + 重注册 Finder 扩展
open /Applications/Chain.app
sleep 1 && pluginkit -e use -i com.lursetawet.chain.ChainExtension && killall Finder
```

一行完成版：

```bash
pkill -x Chain; pkill -x ChainExtension; sleep 1 && rm -rf /Applications/Chain.app && cp -R "$(xcodebuild -project Chain.xcodeproj -scheme Chain -configuration Debug -showBuildSettings 2>/dev/null | awk '$1=="BUILT_PRODUCTS_DIR"{print $3}')/Chain.app" /Applications/Chain.app && open /Applications/Chain.app && sleep 1 && pluginkit -e use -i com.lursetawet.chain.ChainExtension && killall Finder
```

## How It Works

1. **主 App** - 菜单栏 app，提供 settings UI（选择右键菜单显示哪些 app，最多 3 个）
2. **FinderSync Extension** - 注册到 Finder，在右键菜单中添加 "Open in X" 和 "New Markdown"
3. **菜单触发** - 用户点击菜单 → Extension 构建 `com.lursetawet.chain://` URL（不用 `chain://`：V2Box 等 app 也声明了 `chain:`，会抢走链接） → macOS 路由到主 App → 主 App 执行 `NSWorkspace.shared.open` 打开目录

## Key Files

| 文件 | 作用 |
|------|------|
| `ChainAppSupport.swift` | 共享类型：31 个支持的 app（enum）、URL scheme 构建/解析、app catalog |
| `ChainSettings.swift` | 主 App 偏好设置，Extension 只读共享配置 |
| `ChainApp.swift` | 主 App 入口、AppDelegate、URL 分发 |
| `ShellCommand.swift` | 命令拼接与各终端运行方式；新增终端时改这里和 `customCommandTerminals`，测试会校验两者一致 |
| `FinderSync.swift` | 右键菜单构建，从 ChainSettings 读取用户选择 |
| `TargetDirectoryResolver.swift` | 目标目录解析（文件→父目录，文件夹→直接使用） |

## Enabling the Extension

1. 编译运行主 App
2. 系统设置 → 隐私与安全性 → 扩展 → Finder
3. 启用 "Chain Extension"

## Code Conventions

- Swift 标准命名规范
- 右键菜单不使用图标
- 文件创建时自动处理重名（添加数字后缀）
- 所有 UI 字符串为英文，定义在 `ChainAppCatalog`
- `@objc` for target-action methods
- `NSWorkspace.shared.open(url)` 用于 Extension → Main App 通信

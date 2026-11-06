# Chain

Chain 是一个很轻的 macOS 菜单栏工具：在 Finder 里右键，就能在终端或编辑器中打开当前目录，也能新建 Markdown 笔记。支持 31 个终端和编辑器，最多选 3 个放进右键菜单，需要 macOS 14 及以上。

[观看 20 秒演示](promo/chain-promo.mp4)（演示动画，不是录屏）

## 安装

需要完整的 Xcode，不需要 Apple 账号。clone 后在仓库根目录执行：

```sh
scripts/install_local.sh
```

脚本会编译 Release 版，做本地签名，然后安装到 `/Applications/Chain.app`，并重启 Finder。本地签名不会过期，但只适用于在自己的 Mac 上构建，直接把 App 拷给别人时会被 Gatekeeper 拦下。

首次使用时，在系统设置 → 通用 → 登录项与扩展中启用 Chain 的 Finder 扩展。系统版本不同，入口可能略有不同。

重新构建后，系统可能会再次询问是否允许 Chain 控制终端。

## 使用

- **右键菜单：** 在 Finder 里右键文件夹或空白处，选择 `Open in …` 或 `New Note`。
- **菜单栏：** 点击顶部的 Chain 图标，选择要放进右键菜单的 App、设置自定义命令和开机启动。
- **右键菜单不见了：** 点菜单栏里的 `Not Showing?` 重新注册扩展。

## 开发

运行测试（不需要任何密钥）：

```sh
for t in Tests/Chain*Tests.swift; do
  swiftc -parse-as-library -o /tmp/chain_test Chain/ChainAppSupport.swift Chain/ChainSettings.swift Chain/ShellCommand.swift ChainExtension/TargetDirectoryResolver.swift "$t" && /tmp/chain_test || break
done
```

项目结构和约定见 [AGENTS.md](AGENTS.md)。`scripts/` 里还保留了依赖 Apple 开发者账号的自动重建工具，只有改回开发签名时才需要，见 [scripts/README.md](scripts/README.md)。

## 协议

Chain 按 [PolyForm Noncommercial License 1.0.0](LICENSE.md) 发布：源码公开，可用于个人和其他非商业用途，不允许商业使用。如需商业授权，请联系作者。

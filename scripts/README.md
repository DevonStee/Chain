# Chain 自动重编译与安装

> 本机现在用 `scripts/install_local.sh` 做本地签名安装，不需要 Apple 账号，也不会过期，自动修复任务已停用。以下内容只在改回开发签名时才需要。

此仓库提供可在 clone 后安装的自动维护工具，入口为 `install_auto_repair.py`。当前机器的免费开发描述文件有效期为一周；其他团队的有效期以各自描述文件为准。此 LaunchAgent 在用户登录时检查本次开机是否已经修复；每次重启后第一次登录会重新构建安装。后台每 30 分钟检查一次，主 App 或 Finder 扩展的描述文件不足两天时也会重新构建。Xcode 可能继续使用尚未过期的描述文件，临近过期的成功构建最多每六小时一次；描述文件已过期时不受此限制。失败后下一次检查会重试。

脚本先执行带 `-allowProvisioningUpdates` 的 Xcode 构建，验证主 App、扩展签名和新描述文件，再准备完整安装包、备份原 App，删除 `/Applications/Chain.app` 并复制新版。安装失败会尝试恢复原 App；构建失败不会删除原 App。成功后启动 Chain、重新注册扩展并重启 Finder。

需要保留此仓库在当前位置，并保留 Xcode 已登录的 Apple 开发者账号和签名钥匙串。续期需要网络；登录后自动运行，未登录时不会构建。更新时 Finder 会重启，正在进行文件操作时可先关闭自动化。

## 首次安装或换一台 Mac

完整 Xcode 需已安装并选为当前开发工具目录，Apple 账号需在 Xcode → Settings → Accounts 中登录。使用本机可用的 Development Team；不能默认另一位用户有权限使用仓库原作者的团队。

在当前 clone 的根目录执行：

```sh
/usr/bin/python3 scripts/install_auto_repair.py --team YOUR_TEAM_ID
```

替换为自己的 10 位 Team ID。安装器同步完成首次 Chain 构建、签名与安装，再安装后台任务，不依赖预先安装的 Chain。`--team` 会保存在本机 `config.json`，自动构建继续使用该团队，仓库里的作者团队不会被脚本改写。标识符若已被其他团队注册，请按 `AGENTS.md` 的流程配置该用户的 Bundle ID 和 App Group。

已确认项目默认团队可用，或已保存团队设置时，安装命令可简化为：

```sh
/usr/bin/python3 scripts/install_auto_repair.py
```

只读查看是否需要修复：

```sh
/usr/bin/python3 scripts/chain_auto_repair.py --check
```

手动强制重新编译安装：

```sh
/usr/bin/python3 scripts/chain_auto_repair.py --force
```

停止自动化（保留 Chain 和日志）：

```sh
/usr/bin/python3 scripts/install_auto_repair.py --uninstall
```

LaunchAgent：`~/Library/LaunchAgents/com.lursetawet.chain.auto-repair.plist`

系统设置中的后台任务显示为 **Chain Auto Build**。安装器编译同名原生启动程序，用已安装 Chain 的证书签名，并将后台任务关联到该启动程序的 App bundle。启动程序位于 `~/Library/Application Support/ChainAutoRepair/Chain Auto Build.app`。

状态及构建日志：`~/Library/Application Support/ChainAutoRepair/`，构建日志为 `build.log`，只保留最近一次。

后台日志：`~/Library/Logs/ChainAutoRepair/repair.log` 与 `error.log`。

离线检查（不访问 Apple API，不需要密钥）：

```sh
/usr/bin/python3 -m unittest discover -s Tests -p 'test_auto_repair.py'
```

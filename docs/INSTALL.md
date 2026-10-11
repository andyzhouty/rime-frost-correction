# 安装与回退

## 平台对应关系

| 系统 | 前端 | 默认用户目录／安装方式 |
| --- | --- | --- |
| Windows | 小狼毫 | `%APPDATA%\Rime`；自定义位置传 `-UserDir` |
| macOS | 鼠须管 | `~/Library/Rime` |
| Linux | Fcitx5 | `$XDG_DATA_HOME/fcitx5/rime`，默认 `~/.local/share/fcitx5/rime` |
| Linux | IBus | `$XDG_CONFIG_HOME/ibus/rime`，默认 `~/.config/ibus/rime` |
| Linux | Fcitx | `$XDG_CONFIG_HOME/fcitx/rime`，默认 `~/.config/fcitx/rime` |
| Android | 同文／带 Rime 的前端 | 使用应用的导入与部署功能；不假设固定的外部存储目录 |

用户目录依据 [Rime 官方说明](https://github.com/rime/home/wiki/UserData)。Linux 发行版可能单独打包 Lua 和 Octagram 插件，请检查前端所用的 librime；只有 Lua 或没有语言模型插件的安装不满足默认方案要求。

## 桌面安装

1. 安装支持 Lua ≥5.3 和 Octagram 的 Rime 前端，以及 Python ≥3.10。
2. 克隆仓库，运行 README 中对应平台的脚本。脚本在仓库内创建 `.venv`，不往系统 Python 全局安装依赖。
3. 安装器下载锁定版本的通用词库和 `zh-moqi.gram`，核验大小与 Git 对象校验值，再写入用户目录。
4. 在前端重新部署并选择“白霜纠错增强”。辅助棱镜方案是内部依赖，不需要加入菜单。

通用词库以独立目录 `frost_correction_upstream` 安装，主词典名为 `frost_correction_base`，不会覆盖原白霜词库。安装器不触碰现有 `rime.lua`、其他方案的自定义配置或用户词典。

现有 `default.custom.yaml` 会先备份，再解析和添加本方案到菜单；配置值保留，但 YAML 注释和排版可能变化。不希望改动该文件时使用 `--no-menu`，自行在前端启用方案。复杂的列表索引补丁或其他自定义合并逻辑，应选择手动启用并检查最终菜单。

```sh
# 指定任何前端的真实用户目录
sh install.sh --user-dir /path/to/rime --no-menu
```

若已有的 `zh-moqi.gram` 与固定版本不同，安装器停止，避免更换其他方案共用的模型。可生成导入包后重命名模型，并按 CONFIGURATION 文档调整配置再手动安装。

## Android

在电脑上执行 `--package-dir` 生成目录，复制到手机后通过前端导入。目录必须是新目录，避免混入已有文件。也可在有 Python 的 Termux 环境准备包，但它不能自动访问应用私有目录。

[同文官方发布说明](https://github.com/osfans/trime/releases)介绍了应用存储与文件导入的变化：新版可通过系统文件选择器导入，不能假设 `/sdcard/rime` 可直接使用。导入生成目录里的内容，保持 `lua/frost_correction` 和 `frost_correction_upstream` 目录结构；在方案管理中启用 `frost_correction`，再部署。其他 Android 前端需要确认 Rime 插件实际支持 Lua 和 Octagram；名称相同不代表插件能力相同。

手机上的具体导入菜单随版本变化，本文不宣称已进行 Android 实机验收。默认模型较轻；约 380 MiB 的可选万象模型应结合手机内存与前端限制决定是否启用。

## 离线与手动安装

安装器锁定的上游版本与文件在 `scripts/upstream-lock.json`。准备该版本的干净上游白霜检出目录，再执行：

```sh
.venv/bin/python scripts/install.py --source-dir /path/to/clean/rime-frost --user-dir /path/to/rime
```

Windows 的解释器路径为 `.venv\Scripts\python.exe`。离线目录必须通过锁定文件的校验；不接受从个人运行目录复制出的词库。

## 回退

每次安装输出一个 `restore.json` 路径，备份位于用户目录的 `.frost-correction-backups`。关闭输入法或停止使用本方案后执行：

```sh
.venv/bin/python scripts/install.py --rollback /path/to/restore.json
```

回退恢复安装前存在的文件，移除本次新增文件，再由前端重新部署。安装后改过的文件不会被直接覆盖，需先保存修改。学习文件和 Rime 用户词典不在回退范围内；如果启用了生成式 GC，应关闭该选项并重启输入法进程。

Android 导入不会执行桌面安装器的事务备份，导入前使用前端的配置导出功能保存原配置；恢复通过同一前端的导入功能完成。

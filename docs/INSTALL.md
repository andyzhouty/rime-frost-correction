# 安装、常见问题与回退

第一次安装可以直接阅读自己系统对应的步骤。默认设置适合先试用，模型更换和其他高级选项可以以后再了解。

## 安装前准备

先确认原来的 Rime 能正常输入中文，再备份它的**用户目录**。这个目录保存输入方案、设置和学习数据。通常可以从输入法菜单打开；找不到时可以参考下面的默认位置。

| 系统／输入法 | 默认用户目录 |
| --- | --- |
| Windows／小狼毫 | 在文件资源管理器地址栏输入 `%APPDATA%\Rime` |
| macOS／鼠须管 | 在 Finder 中选择“前往文件夹”，输入 `~/Library/Rime` |
| Linux／Fcitx5 | `~/.local/share/fcitx5/rime` |
| Linux／IBus | `~/.config/ibus/rime` |
| Linux／Fcitx | `~/.config/fcitx/rime` |
| Android | 在输入法设置中使用配置导出或备份功能 |

安装位置可以自定义，以上默认目录依据 [Rime 官方文档](https://github.com/rime/home/wiki/UserData)。Linux 设置过 XDG 目录变量时，也应以实际目录为准。

### 两个输入法组件

本方案需要输入法提供以下组件，通常由前端安装包或发行版软件包提供：

- **librime-lua，Lua 5.3 或更新版本**：运行纠错和学习代码。还需支持 `lua_translator@*模块名` 这种模块加载方式。
- **Octagram**：利用语言模型判断哪些词更适合组合在一起。

查看输入法发行说明或插件列表，确认有这两个组件。Linux 的插件可能需要单独安装，软件包名称因发行版而异。部署报错时，可在日志中搜索 `lua_translator`、`script_translator`、`grammar` 等关键词，判断是缺少组件还是配置加载失败。

### Python 与项目文件

安装器需要 Python 3.10 或更新版本。Windows 可从 [Python 官网](https://www.python.org/downloads/)下载安装，安装时勾选 **Add python.exe to PATH**。macOS 和 Linux 可使用已有的 Python 3，先用 `python3 --version` 确认版本；Windows 使用 `python --version`。

在仓库页面点击 **Code → Download ZIP**，将文件解压到一个方便找到的地方。后面的命令都在含有 `README.md`、`install.ps1` 和 `install.sh` 的文件夹中运行。

## Windows：小狼毫

1. 打开解压后的项目文件夹。
2. 在文件资源管理器的地址栏输入 `powershell`，按回车。这会在当前文件夹打开命令窗口。
3. 复制下面的命令，粘贴到窗口并按回车：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

4. 等待显示“安装完成”。记录最后显示的“回退记录”路径，恢复原配置时会用到它。
5. 在小狼毫的菜单中选择“重新部署”。完成后打开输入方案菜单，选择“白霜纠错增强”。
6. 在文本框输入 `nihao`，确认出现中文候选；再试试 `jintain`，观察纠错候选旁的 `≈`。

如果你把小狼毫用户目录设在其他位置，把实际路径填入引号：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -UserDir "D:\Rime"
```

这里的 `D:\Rime` 是示例路径，应替换成你自己的用户目录。

## macOS：鼠须管

1. 打开“终端”，输入 `cd `（末尾留一个空格），把解压后的项目文件夹拖入终端，按回车。
2. 执行安装命令：

```sh
sh install.sh
```

3. 看到“安装完成”后记录回退路径。
4. 在鼠须管菜单中选择“重新部署”，完成后选择“白霜纠错增强”。

## Linux：Fcitx5、IBus 或 Fcitx

在项目文件夹打开终端，按自己的输入法执行其中一条命令：

```sh
# Fcitx5
sh install.sh --frontend fcitx5

# IBus
sh install.sh --frontend ibus

# Fcitx
sh install.sh --frontend fcitx
```

安装完成后重新部署，在 Rime 的输入方案菜单中选择“白霜纠错增强”。如果实际用户目录与默认位置不同，使用：

```sh
sh install.sh --user-dir "/你的/Rime用户目录"
```

路径需要替换为实际位置。若提示无法创建 Python 虚拟环境，安装发行版提供的 Python `venv` 组件后再试。

## Android：通过输入法导入

先在电脑上准备文件，再交给手机上的输入法导入。

**Windows 电脑**在项目文件夹运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -PackageDir .\android-rime
```

**macOS 或 Linux 电脑**运行：

```sh
sh install.sh --package-dir ./android-rime
```

接下来：

1. 将生成的 `android-rime` 文件夹复制到手机上。生成时这个文件夹应尚不存在。
2. 在输入法设置中备份现有配置，再使用文件导入功能，导入文件夹里的内容。
3. 保持 `lua/frost_correction` 等子目录结构完整。
4. 在方案管理中启用 `frost_correction`，然后部署，选择“白霜纠错增强”。

[同文官方发布说明](https://github.com/osfans/trime/releases)提供了存储与导入功能的说明。具体按钮名称随版本变化；其他 Android 前端也需确认支持前面提到的两个组件。

## 安装脚本会做什么

脚本先准备运行环境，下载固定版本的白霜通用词库和轻量模型，再将本方案写入 Rime 用户目录。它会备份需要改动的文件，并将“白霜纠错增强”加入方案菜单。最后的重新部署由你在输入法中完成。

菜单配置文件 `default.custom.yaml` 会重新保存，原有配置值保留，注释和排版可能变化。已经有复杂菜单配置的用户可以手动启用方案：

```sh
sh install.sh --no-menu
```

Windows 可在首次准备好安装环境后，直接调用安装器：

```powershell
.\.venv\Scripts\python.exe scripts\install.py --no-menu
```

## 常见问题

| 现象 | 可以先这样处理 |
| --- | --- |
| 提示找不到 Python | 安装 Python，并重新打开命令窗口；确认版本命令能够运行 |
| 下载中断或超时 | 检查网络，重新执行安装命令；已下载并校验成功的资源会复用 |
| 安装后没有新方案 | 确认安装到了正确用户目录，重新部署，再查看输入方案菜单 |
| 新方案没有中文候选 | 查看部署日志，检查 Lua 与 Octagram 组件，以及词库是否编译成功 |
| 提示已有 `zh-moqi.gram` 版本不同 | 安装器已停止；保留现有模型，使用[高级配置](CONFIGURATION.md#更换语言模型进阶)方法安排模型名称 |
| 回退时提示文件安装后有修改 | 先把修改后的文件另存一份，再处理；安装器会保护这些修改 |

## 恢复安装前的配置

先停止使用本方案。在项目文件夹中运行回退命令，将路径替换为安装结束时显示的 `restore.json` 路径。

**Windows：**

```powershell
.\.venv\Scripts\python.exe scripts\install.py --rollback "回退记录的完整路径\restore.json"
```

**macOS 或 Linux：**

```sh
.venv/bin/python scripts/install.py --rollback "/回退记录的完整路径/restore.json"
```

完成后重新部署。回退会恢复本次安装前的文件，保留使用期间积累的学习数据。如果曾开启生成式 GC，再重启输入法程序。

Android 使用前端导入先前备份的配置，完成后重新部署。

## 离线安装（进阶）

安装器需要的上游版本和文件清单在 `scripts/upstream-lock.json`。准备该版本的白霜源码目录后，可以直接读取这些文件：

```sh
.venv/bin/python scripts/install.py --source-dir "/白霜源码目录" --user-dir "/Rime用户目录"
```

Windows 使用 `.\.venv\Scripts\python.exe`。安装器会核对文件版本，确保它们与清单一致。

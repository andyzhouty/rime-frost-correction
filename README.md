# 白霜纠错增强 · rime-frost-correction

基于 Rime 和白霜通用词库的全拼纠错方案。通过有预算的错误路径搜索、统计上下文和本地选择学习，处理鼻音、邻键、漏键及交换错误。

- 正确输入保留正常候选，真实纠错显示 `≈`，预编辑保留实际输入字母。
- 使用 Rime 原生词典查找与造句，Lua 负责查询调度及候选合并。
- 用户偏好由实际提交累积，半衰期五年；学习数据只存在使用者本机。
- 默认使用轻量统计模型，可选万象模型和 Lua 5.4 生成式 GC。

**公开版不包含个人定制词库、手工词频、自定义短语、原始探索记录或 MSVC 实验。** 仓库没有预编译 DLL，也不要求自行编译 Rime。安装时下载固定版本的上游白霜通用基础词库；不读取发布者本机词库。

## 使用

需要已安装的 Rime 前端，包含 **librime-lua（Lua ≥5.3）和 Octagram 插件**，并支持 `lua_translator@*模块名` 自动加载。安装器需要 Python ≥3.10、网络和少量 Python 依赖；第一次重新部署会编译词库，请耐心等待。

下载或克隆仓库后，在仓库目录运行：

```powershell
# Windows／小狼毫；自定义用户目录请传入 -UserDir
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

```sh
# macOS／鼠须管
sh install.sh
# Linux／Fcitx5；IBus 使用 --frontend ibus
sh install.sh --frontend fcitx5
```

完成后，在输入法中**重新部署**，选择“白霜纠错增强”。安装器不自动重启输入法或替换其程序。

Android 的应用私有目录不能由通用桌面脚本直接写入。先生成导入目录：

```sh
sh install.sh --package-dir ./android-rime
```

再通过同文等前端的文件导入功能导入、启用 `frost_correction` 并部署。具体目录与权限由前端决定，详见[安装与回退](docs/INSTALL.md)。

## 文档

- [探索过程与当前技术架构](docs/EVOLUTION_AND_ARCHITECTURE.md)：只保留设计演进与结论，不发布原始记录。
- [Windows、macOS、Linux、Android 安装与回退](docs/INSTALL.md)
- [配置、学习数据与兼容性](docs/CONFIGURATION.md)
- [验证方法与公开版边界](docs/VALIDATION.md)
- [上游来源与授权](THIRD_PARTY_NOTICES.md)

公开版默认词库和模型与开发者本机定制环境不同，不能直接套用其跑分。跨平台复用的是 Rime/Lua 方案；当前没有把所有系统实机验证描述为已完成。

## 授权

GPL-3.0，见 [LICENSE](LICENSE)。白霜及其上游贡献者的相关代码与资源保留原有授权；模型由安装器从上游下载，不随 Git 仓库分发。

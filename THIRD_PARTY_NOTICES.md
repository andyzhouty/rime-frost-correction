# 使用到的开源项目

本项目建立在 Rime 与白霜生态之上。下面列出主要依赖，方便了解各部分从哪里来。

| 项目 | 在本项目中的作用 | 获取方式 |
| --- | --- | --- |
| [Rime](https://github.com/rime/librime) | 输入法引擎，负责词典查询与中文组句 | 由小狼毫、鼠须管等输入法程序提供 |
| [白霜 rime-frost](https://github.com/gaboolic/rime-frost) | 通用词库、基础方案思路，以及部分 Lua 逻辑 | 安装器下载固定版本的字表、基础词库、扩展词库、杂项和轻量模型 |
| [librime-lua](https://github.com/hchunhui/librime-lua) | 在 Rime 中运行 Lua 纠错与学习代码 | 由输入法安装包或发行版插件包提供 |
| [Octagram](https://github.com/lotem/librime-octagram) | 使用统计语言模型改善组句 | 由输入法安装包或发行版插件包提供 |
| [RIME-LMDG](https://github.com/amzxyz/RIME-LMDG) | 可选万象统计模型 | 按配置文档从上游获取 |
| [PyYAML](https://github.com/yaml/pyyaml) | 帮助安装器读取和更新 YAML 配置 | 安装脚本准备 Python 环境时安装 |

## 授权说明

本项目采用 [GPL-3.0](LICENSE)。白霜采用 GPL-3.0，来自上游的代码保留相关来源说明；下载资源附带的 LICENSE 与原有说明一并保存。

PyYAML 采用 MIT 许可。Rime、插件和可选模型各自遵循对应项目的授权，使用或再次分发时请阅读上游说明。

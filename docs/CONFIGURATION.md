# 配置与学习数据

新建 `frost_correction.custom.yaml`，按需修改：

```yaml
patch:
  menu/page_size: 6
  correction/generational_gc: false
```

修改后重新部署。此文件和本地用户数据不要提交到公开仓库。

## 可选模型

默认 Octagram 语言模型为 `zh-moqi`。纠错代码允许读取可选万象统计模型提供上下文对比；默认安装不下载该大模型，缺少文件时跳过额外证据。

从 [RIME-LMDG 官方仓库](https://github.com/amzxyz/RIME-LMDG)下载兼容的 `wanxiang-lts-zh-hans.gram`，放入用户目录，再设置：

```yaml
patch:
  grammar/language: wanxiang-lts-zh-hans
  correction/context_model: wanxiang-lts-zh-hans
```

独立的补充译码仍使用 `zh-moqi`，因此不要删除默认模型。不同模型会改变候选与延迟，不能据此声称公开版与本地定制版结果一致。

## 可选生成式 GC

Lua 5.4 前端可设置 `correction/generational_gc: true`。Lua 5.3 无该模式，初始化会保留原 GC。开启后影响同一进程的 Lua 状态，并非仅对一个候选有效；回退需要关闭选项并重启前端。项目不替换原生 DLL、不关闭 GC。

## 本地学习

提交产生的偏好写入用户目录 `frost_correction_selection.tsv`；原生用户词典由 Rime 管理。算法代码可公开，已有词语和计数不能随发布者的环境打包。

偏好随实际选择累积，五年半衰期。只有存在于候选中的词才能被提升，不会从记录中凭空制造候选。历史星号不会单独构成强制置顶理由。

## Shift 与显示

公开方案使用 Rime 自身的 Shift 配置：中文输入中单独 Shift 提交原始英文。没有捆绑 Windows 专用快捷键守护程序，组合键行为以对应前端为准。

正确输入无 `≈`，真实纠错显示一个 `≈`。查看预编辑时应看到实际输入字母，避免将修复后的拼音伪装成用户输入。

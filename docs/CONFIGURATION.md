# 设置与输入习惯学习

默认设置可以直接使用。这篇文档介绍候选标记、学习方式，以及几个常用的可选设置。

## 先认识候选旁的标记

| 标记 | 意思 |
| --- | --- |
| `≈` | 方案尝试修正了你的拼音，这个词是纠错候选 |
| `*` | 这个词来自 Rime 的用户词典，通常与过去的输入有关 |
| `∞` | 由 Rime 组合出的整句候选 |

输入栏会保留你实际敲下的字母，可能按音节添加空格。这样可以看出是否输错，再决定选择哪个候选。

## 经常使用的词会怎样学习

当你选择并提交一个词时，方案会累积对它的偏好。反复明确选择同一个词后，它更有机会排到前面；带星号本身不会让它自动置顶。

偏好衰减得很慢：半衰期为五年，意思是如果以后完全不再使用，五年后留下的偏好约为原来的一半。它只调整已有候选的顺序。

本方案的偏好记录保存在 Rime 用户目录的 `frost_correction_selection.tsv`。备份用户目录时，可以一并保存这个文件；Rime 自身还会维护原生用户词典。

## 修改设置的方法

1. 打开 Rime 用户目录，位置见[安装指南](INSTALL.md#安装前准备)。
2. 新建文本文件 `frost_correction.custom.yaml`。Windows 请检查文件名末尾没有额外的 `.txt`。
3. 用文本编辑器写入配置并保存，再在输入法中重新部署。

例如，每页显示八个候选：

```yaml
patch:
  menu/page_size: 8
```

YAML 使用空格缩进，示例里每行前面是两个空格。多个设置放在同一个 `patch:` 下；如果文件已经存在，添加设置即可。

## 开启生成式 GC（进阶）

GC 是 Lua 清理暂时不用的数据的机制。Lua 5.4 的生成式 GC 在部分环境下有助于降低延迟，默认关闭。确认输入法使用 Lua 5.4 后，可以尝试：

```yaml
patch:
  correction/generational_gc: true
```

重新部署后测试输入是否正常。Lua 5.3 会继续使用原来的回收方式。这个设置可能影响同一输入法进程里的其他 Lua 组件；想恢复时改成 `false`，重新部署并重启输入法程序。

## 启用万象与 zh-moqi 双模型（进阶）

语言模型用于判断哪些词语搭配更常见。默认安装只下载较轻的 `zh-moqi`：主查询与补充查询都使用它。双模型是可选配置，启用后由万象负责主查询，`zh-moqi` 提供补充候选，万象的词组证据帮助决定是否提升补充候选。

需要尝试万象模型时，从 [RIME-LMDG 官方项目](https://github.com/amzxyz/RIME-LMDG)获取兼容的 `wanxiang-lts-zh-hans.gram`，放到 Rime 用户目录，再设置：

```yaml
patch:
  grammar/language: wanxiang-lts-zh-hans
  correction/context_model: wanxiang-lts-zh-hans
```

重新部署后生效。请保留 `zh-moqi.gram` 与 `wanxiang-lts-zh-hans.gram` 两个文件。万象模型较大，手机上应先考虑可用内存。两个配置项分别控制主查询模型和额外词组证据；只放入万象文件而不修改 `grammar/language`，主查询仍使用 `zh-moqi`。

想恢复默认主查询时，将 `grammar/language` 改回 `zh-moqi` 并重新部署；若仍保留万象文件，额外词组证据仍可使用它。更详细的查询分工见[架构文档](EVOLUTION_AND_ARCHITECTURE.md#2-上下文判断)。

如果安装时遇到同名 `zh-moqi.gram` 冲突，可以先用[导入目录](INSTALL.md#android通过输入法导入)方式准备文件。将导入目录中的模型重命名为 `frost-correction-moqi.gram`，在安装配置前完成以下调整：

1. 将 `frost_correction.schema.yaml` 中 `grammar` 下的 `language` 改成 `frost-correction-moqi`。
2. 将 `lua/frost_correction/dual.lua` 中设置 `grammar/language` 的 `zh-moqi` 改成 `frost-correction-moqi`。
3. 将准备好的文件复制到用户目录，手动启用 `frost_correction`，再重新部署。

这项操作适合熟悉配置的用户。更换模型后，候选顺序和输入速度都可能变化。

## Shift 切换

中文输入过程中，单独按 Shift 会提交正在输入的英文字母。快捷键组合的具体行为由所用的输入法程序处理。

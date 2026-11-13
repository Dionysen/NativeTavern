# NativeTavern 文档索引

本目录描述仓库的**整体架构**、**代码分层与文件树**，以及**功能清单与边界**。与产品/玩法相关的专题说明仍保留在现有独立文档中。

| 文档 | 内容 |
|------|------|
| [architecture.md](./architecture.md) | 运行时架构、分层依赖、数据流、文件树约定、跨平台宿主 |
| [features.md](./features.md) | 功能模块详表：职责、代码位置、持久化、测试、边界与已知耦合 |

## 已有专题文档

| 文件 | 说明 |
|------|------|
| [story-play-design.md](./story-play-design.md) | 故事/游玩线设计 |
| [playable-world-spec.md](./playable-world-spec.md) 等 | 可游玩世界规格与 backlog |
| [rpg_scenario_contract.md](./rpg_scenario_contract.md) | RPG 场景包契约 |
| [chat_generation_extensions.md](./chat_generation_extensions.md) | 聊天生成扩展 |
| [voice_integration_device_gate.md](./voice_integration_device_gate.md) | 语音设备门控 |

## 维护约定

- 代码路径以 `lib/`、`test/` 为准。
- 分层或 schema 大改时更新 `architecture.md`；新功能更新 `features.md` 并写清边界。

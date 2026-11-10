# 内置角色卡 / Built-in Characters

把要内置的角色卡 PNG（SillyTavern 风格，内嵌 `chara` / `ccv3`）放到：

```text
assets/characters/images/
```

可选：同名 JSON 源文件可放在 `assets/characters/json/` 便于编辑，**运行时只加载 `images/` 下的 PNG**。

应用首次启动时会扫描该目录并导入；已存在同 ID 的角色会跳过。

目录路径请保留（`pubspec.yaml` 已声明 `assets/characters/`），即使暂时没有卡文件也可以。

# 笑笑 Codex 皮肤

这是笑笑桌宠的 Codex 原生皮肤，不修改 Codex 应用包，也不影响官方签名、
自动更新或数据目录。

皮肤包含：

- 88 帧 Codex v2 桌宠：待机、奔跑、招手、报错、专注、庆祝和任务提醒
- 暖奶油白、漆红、墨棕、场景青的明暗界面配色
- Rosé Pine Dawn / Moon 代码主题
- 一键安装和可恢复备份

## 安装

要求 Codex `26.721.41059` 或更新版本。

```bash
./scripts/install-codex-skin.sh
```

安装程序会：

1. 验证官方 Codex 的 bundle identifier。
2. 验证精灵图为 `1536 × 2288` 且包含透明通道。
3. 安装到 `~/.codex/pets/xiaoxiao/`。
4. 备份 `~/.codex/config.toml`，再只更新外观和桌宠字段。
5. 保留所有非外观字段，并将配置与备份限制为当前用户读写（0600）。

Codex 正在运行时，部分颜色会即时刷新；桌宠未刷新时，重新打开 Codex
即可。设置路径为 `Settings → Personalization → Pets`。

安装脚本可以重复运行，同一字段不会重复写入。自动化测试使用隔离的虚拟配置，
验证幂等性、非外观字段保留和文件权限，不会读取或提交你的真实 Codex 配置。

## 恢复

安装前的配置保存在 `~/.codex/theme-backups/`。运行：

```bash
./scripts/uninstall-codex-skin.sh
```

脚本只删除本皮肤的桌宠目录，并恢复安装时保存的配置快照。

## 重新生成精灵图

`source-green.png` 是无人物原始照片的生成素材。使用系统 Swift 工具移除绿幕、
补齐 Codex v2 网格并生成 RGBA 精灵图：

```bash
xcrun swift Tools/make_codex_pet.swift \
  CodexSkin/source-green.png CodexSkin/spritesheet.png
```

生成后应为 `1536 × 2288`、8 列 × 11 行、包含透明通道的 PNG。

## 兼容性

Codex 的自定义桌宠格式属于产品功能，但具体尺寸和配置字段可能随版本更新。
安装脚本会在格式不匹配时停止，不会改写 Codex 应用包。

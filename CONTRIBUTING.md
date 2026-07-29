# Contributing

感谢你愿意让笑笑更好玩。小修复、场景规则、台词、辅助功能和文档改进都欢迎。

## 开始之前

1. 对较大的功能先开 Issue，说明用户问题、预期行为和隐私影响。
2. 安全问题不要开公开 Issue，请按 [SECURITY.md](SECURITY.md) 私密上报。
3. 不要提交人物原始照片、聊天截图、账号信息、密钥或含隐私的录屏。
4. 角色素材不属于 MIT；新角色素材必须有清楚、可验证的授权。

## 本地开发

要求 macOS 13+ 和 Xcode Command Line Tools。

```bash
xcode-select --install
./scripts/security-check.sh
./scripts/test.sh
./build.sh
open "笑笑桌宠.app"
```

源码没有第三方运行时依赖。构建会生成 Apple Silicon 与 Intel 通用 App，并
进行临时签名。

## Pull Request 要求

- 每个 PR 聚焦一个清楚的问题。
- 用户可见变化同步更新 README、MANUAL 或 CHANGELOG。
- 新场景规则必须在 `Tests/AwarenessClassifierTests.swift` 增加覆盖。
- 新权限、网络、遥测或持久化行为必须先更新 PRIVACY 和 SECURITY。
- 检查 60%、75%、100% 三档下的气泡、角色和状态徽章没有截断。
- 不提交 `.app`、`dist/`、原始照片、凭据或本机配置。

PR 合并前应通过：

```bash
./scripts/security-check.sh
./scripts/test.sh
./build.sh
codesign --verify --deep --strict "笑笑桌宠.app"
```

## 代码与文字风格

- Swift 保持小函数、明确命名和主线程 UI 更新。
- 场景判断优先使用最小必要信息，不新增历史记录。
- 台词友好、简短，不羞辱用户，也不提供高风险建议。
- Issue 和截图先打码，尤其是窗口标题、聊天内容和文件路径。

参与本项目即表示你同意遵守 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

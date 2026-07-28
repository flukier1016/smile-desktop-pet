# 笑笑桌宠

<p align="center">
  <img src="Assets/pet.png" width="260" alt="笑笑桌宠 Q 版角色">
</p>

<p align="center">
  一只会蹦、会接话、会被你喂胖一点点的原生 macOS 桌宠。
</p>

## 下载

打开 [Releases](../../releases/latest)，下载以下任一文件：

- `SmilePet-v1.1.0-macos-universal.dmg`：推荐，打开后把 App 拖到“应用程序”。
- `SmilePet-v1.1.0-macos-universal.zip`：解压后直接运行。
- `SHA256SUMS.txt`：用于校验下载文件是否完整。

支持 macOS 13 或更高版本，同时兼容 Apple Silicon 和 Intel Mac。

> 当前版本使用临时签名，尚未进行 Apple 公证。第一次启动时，请在 Finder 中右键“笑笑桌宠”，选择“打开”，再确认一次。不要使用来源不明的二次打包版本。

## 好玩的地方

- 单击头部：摸摸头，随机回应并冒爱心。
- 单击身体：戳一下，她会弹跳反击。
- 双击：旋转、撒彩带，快乐加载到 100%。
- 拖拽：把她放到屏幕任意位置，下次启动会记住。
- 调整大小：右键或菜单栏选择迷你／标准／大只；按住 `Option` 滚轮可连续缩放。
- 右键：喂零食、夸夸、抽今日运气、出去散步、暂时躲起来。
- 菜单栏笑脸：随时召回、开启鼠标穿透、安静十分钟或退出。
- 自动碎碎念：喝水提醒、摸鱼批准、随机小剧场。

## 隐私

笑笑桌宠完全离线运行，不联网，不含分析统计，不收集任何数据，也不会申请相机、麦克风、文件或通讯录权限。详见 [PRIVACY.md](PRIVACY.md)。

## 完整使用说明

安装、首次打开、菜单功能、开机启动、更新、卸载及常见问题均在 [用户使用手册](MANUAL.md) 中说明。Release 安装包也附带一份 `开始使用.txt`。

## 从源码构建

仅开发者需要这一步：

```bash
xcode-select --install
git clone https://github.com/flukier1016/smile-desktop-pet.git
cd smile-desktop-pet
./build.sh
open "笑笑桌宠.app"
```

构建脚本会生成 Apple Silicon＋Intel 通用 App，并进行本地临时签名。

打 Release 包：

```bash
./scripts/package-release.sh 1.1.0
```

产物位于 `dist/`。

## 许可

- Swift 源代码采用 [MIT License](LICENSE)。
- `Assets/pet.png`、`Assets/AppIcon.icns` 及其角色形象不在 MIT 授权范围内，详见 [ASSET_NOTICE.md](ASSET_NOTICE.md)。
- 原始人物照片从未提交到本仓库或 Release。

发现问题或有新玩法建议，欢迎提交 [Issue](../../issues)。

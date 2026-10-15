# SmilePet Landing Page

笑笑桌宠的官方产品页，使用 React 作为构建时模板，TypeScript、Vite 和 Tailwind CSS 构建。
线上直接发送静态 HTML 与约 5.4 KB 的交互脚本，不下载 React 运行时。

## 本地开发

```bash
pnpm install
pnpm dev
```

## 验证

```bash
pnpm lint
pnpm build
pnpm test
```

## Railway

`railway.json` 已包含生产构建、启动、健康检查与失败重启配置。部署时将服务根目录
设为 `smilepet-landing`，或直接在本目录执行 `railway up`。

生产服务启用 Railway 内置 CDN。HTML 同时用 `s-maxage` 与 Fastly
`Surrogate-Control` 声明一小时共享缓存，并用 `max-age=60` 兼容 Railway 当前的
HTML TTL 行为与浏览器短缓存；成功部署后 Railway 自动清理全部 CDN 缓存。

```bash
railway cdn enable --json
railway cdn update \
  --html-caching auto \
  --default-ttl 1h \
  --swr \
  --purge-on-deploy all \
  --json
```

页面不加载统计、广告、Cookie 或提交表单。App 的完整隐私与安全边界分别记录在
仓库根目录的 `PRIVACY.md` 与 `SECURITY.md`。

## 性能实现

- 构建时输出完整 HTML，浏览器下载 JavaScript 前即可显示产品内容；React 只在开发／构建阶段使用。
- 线上交互只修改 Hero 与场景示例的相关节点；鼠标事件每帧合并，没有 React 渲染或每帧计时器。
- 88 帧精灵使用整张图的合成层位移，只在接近视口时加载；离屏和后台标签页暂停播放。
- 各区域持续动画按可见性暂停；手机减少模糊、阴影和轨道动画，遵循减少动态效果设置。
- 服务启动时缓存文件元数据、HTML/JS/CSS 以及 Brotli/gzip 版本，请求时直接发送；保留 Railway 边缘缓存策略。
- 下载按钮继续指向实际公开发布的稳定版，源码性能版尚未发布前不生成无效安装包链接。
- `pnpm test` 在构建后执行，包含 16 KiB JavaScript 体积预算，防止重新引入大型运行时。

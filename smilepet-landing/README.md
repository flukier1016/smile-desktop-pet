# SmilePet Landing Page

笑笑桌宠的官方产品页，使用 React、TypeScript、Vite 和 Tailwind CSS 构建。

## 本地开发

```bash
pnpm install
pnpm dev
```

## 验证

```bash
pnpm lint
pnpm build
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

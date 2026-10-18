# sandbox-image

[Only Chat](https://github.com/dragon-fish/only-chat) 沙箱容器的基础镜像：Debian trixie，加上 uv 与 Python 3.12（附常用数据处理库）、Node.js 与 pnpm、bun，以及共用一份 headless Chromium 的 Playwright（Python 与 npm 两套包）。

only-chat 自己的 `sandbox/Dockerfile` 以它为基础，再叠上与代码绑定的部分（运行脚本、sandbox-shim、环境变量）。重的工具链在这里构建一次，部署 only-chat 时只需拉取，不再每次从头构建。

```
ghcr.io/onlychathq/sandbox-base
```

## 标签

- `vX.Y.Z`、`vX`：发版标签，only-chat 引用这类标签并固定摘要
- `sha-<commit>`：每次推送 main 的构建
- `latest`：main 的最新构建

## 发版

推送 main 会构建并发布 `sha-*` 与 `latest`；推送 `v*` 标签会额外发布版本号标签。镜像只构建 `linux/amd64`，与 Cloudflare Containers 一致。

改了 `PLAYWRIGHT_VERSION` 时，only-chat 里 `sandbox_exec` 工具说明引用的版本号要同步修改。

## 许可

MIT。

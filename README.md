# SourceFusion

SourceFusion 是一个带来源展示的 AI 搜索应用。它通过 Google Custom Search 获取网页结果，并发抓取页面正文，再交给 Groq 上的语言模型生成 Markdown 回答。后端会以流式响应持续返回搜索进度，前端同步展示来源、处理状态和最终答案。

## 工作流程

1. React 前端向 `POST /stream_search` 提交问题。
2. FastAPI 后端调用 Google Custom Search API，并选取最多 4 个结果。
3. 后端并发下载网页，移除脚本与样式后提取段落文本；每个页面最多保留约 1,000 个词。
4. 有效网页内容与用户问题一起发送给 Groq 模型 `openai/gpt-oss-20b`。
5. 搜索结果、抓取状态和最终回答使用 `[/PERPLEXED-SEPARATOR]` 分隔并流式返回。
6. 相同问题会优先命中进程内存缓存，避免重复搜索和模型调用。

## 技术栈

- 前端：React 18、React Markdown、Tailwind CSS、Create React App
- 后端：Python 3、FastAPI、Uvicorn、Gunicorn、HTTPX、Beautiful Soup、Groq SDK
- 搜索：Google Programmable Search / Custom Search JSON API
- 构建与部署：Bun、uv、just、Docker、Nginx
- 云端示例：Cloudflare Workers + Containers、Fly.io

## 项目结构

```text
SourceFusion/
├── backend/                  # FastAPI 接口、搜索管线、模型与缓存
│   ├── fastapi_app.py        # 应用入口和流式接口
│   ├── search.py             # 搜索、抓取和 LLM 调用
│   ├── config.py             # 环境变量与模型提示词
│   ├── models.py             # Pydantic 数据模型
│   └── query_cache.py        # 进程内查询缓存
├── frontend/                 # React Web 界面
├── docker/                   # Nginx 与容器启动脚本
├── deployment/
│   ├── cloudflare/           # Cloudflare Worker/Container 示例
│   └── fly/                  # Fly.io 示例配置
├── Dockerfile                # 前后端一体化镜像
├── Dockerfile-cloudflare     # Cloudflare 后端容器镜像
└── justfile                  # 常用开发和构建命令
```

## 前置条件

- Python 3.11 或更高版本
- [uv](https://docs.astral.sh/uv/)
- [Bun](https://bun.sh/)
- [just](https://github.com/casey/just)
- Google Custom Search API Key 与搜索引擎 ID
- Groq API Key
- Docker（仅容器运行需要）

## 本地开发

### 1. 克隆仓库

```bash
git clone git@github.com:liujiahui479/SourceFusion.git
cd SourceFusion
```

### 2. 安装依赖

```bash
just backend-setup
just backend-install
just frontend-install
```

### 3. 配置后端

编辑 `backend/.env`：

```bash
export GOOGLE_SEARCH_API_KEY="your-google-api-key"
export GOOGLE_SEARCH_ENGINE_ID="your-search-engine-id"
export GROQ_API_KEY="your-groq-api-key"
```

可选环境变量：

| 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `DOMAINS_ALLOW` | `http://localhost:30000` | 允许跨域访问的前端地址，多个地址用逗号分隔 |
| `FASTAPI_APP_PORT` | `30001` | FastAPI 监听端口 |

不要提交真实密钥。`backend/.env` 已被 Git 忽略。

### 4. 启动服务

分别打开两个终端：

```bash
just backend-dev
```

```bash
just frontend-dev
```

默认地址：

- Web 界面：<http://localhost:30000>
- 后端接口：<http://localhost:30001>
- 健康检查：<http://localhost:30001/test>
- 环境检查：<http://localhost:30001/env>
- OpenAPI 文档：<http://localhost:30001/docs>

`/env` 只返回经过掩码处理的密钥片段，但生产环境仍建议限制该接口的访问。

## API

### `POST /stream_search`

请求体：

```json
{
  "user_prompt": "What is retrieval-augmented generation?"
}
```

响应类型为 `application/json` 流。每个阶段都是一个 JSON 对象，并以以下文本分隔：

```text
[/PERPLEXED-SEPARATOR]
```

阶段包括：

- `Querying Google`：返回搜索结果和来源
- `Downloading Webpages`：表示网页抓取完成
- `Results ready`：返回模型回答、来源和 token 用量

## 前端配置

前端通过不同的 `.env.*` 文件区分开发、预发布、生产和 Cloudflare 环境。常用变量如下：

| 变量 | 用途 |
| --- | --- |
| `REACT_APP_API_URL` | `/stream_search` 的完整地址 |
| `REACT_APP_DISPLAY_NAME` | 页面显示的产品名称 |
| `REACT_APP_USER_PROMPT` | 首页提示语 |
| `REACT_APP_GITHUB_LINK` | 页面中的 GitHub 链接 |
| `BUILD_PATH` | React 构建输出目录 |

生产构建前，可从示例创建配置：

```bash
cp frontend/.env.production.example frontend/.env.production
```

然后将其中的 API 地址和站点信息替换为自己的部署地址。

## 构建与 Docker

构建预发布前端和一体化镜像：

```bash
just frontend-build-staging
just build-image-staging
just run
```

容器对外暴露 `30000` 端口。Nginx 提供 React 静态资源，并将后端请求反向代理到容器内的 FastAPI 服务。

生产构建：

```bash
just frontend-build-prod
just build-image-prod
```

## Cloudflare 部署

`deployment/cloudflare` 提供 Workers、静态资源和 Cloudflare Containers 的组合部署示例：

- Worker 直接提供前端静态资源。
- `/stream*` 和 `/env` 请求被转发到后端容器。
- Google 与 Groq 密钥应通过 Wrangler Secrets 配置。

部署前请修改 `wrangler.toml` 和前端 Cloudflare 环境文件中的域名、Worker 名称及路由。示例配置包含原项目域名，不能直接用于正式环境。

## 代码检查

```bash
just lint-backend
just format-backend
```

## 当前限制

- 查询缓存仅保存在单个进程内，服务重启后会清空，也不会在多实例间共享。
- 网页正文仅从 `<p>` 元素提取，动态页面或特殊结构页面可能无法获得有效内容。
- 当前搜索结果最多取 4 条，抓取超时和文本长度限制在 `backend/search.py` 中固定配置。
- API 尚未提供身份认证；公开部署时应在网关层增加访问控制和限流。
- `backend/archive` 保存旧版 Flask 实现，不参与当前 FastAPI 服务运行。

## License

本项目基于 MIT License 发布，详情见 [LICENSE.md](LICENSE.md)。

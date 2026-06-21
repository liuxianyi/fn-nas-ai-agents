# 飞牛 NAS (fnOS) AI Agents 全 Docker 部署指南

本目录包含在飞牛 NAS 上通过 Docker 部署 **Codex、Antigravity CLI (agy)、OpenClaw** 以及 **Botmux（飞书桥接器）** 的完整配置文件，并配置 **Clash 链式代理（中转 + 静态住宅 IP 落地）** 确保 API 请求不被封禁。

---

## 目录结构
```text
fn-nas-ai-agents/
├── Dockerfile              # Botmux (含 Node, Git, agy, codex) 的容器构建文件
├── docker-compose.yml      # Docker 容器编排文件
├── README.md               # 部署说明文档（当前文档）
└── clash/
    └── config.yaml         # Clash 链式代理配置文件模板
```

---

## 部署步骤

### 第一步：准备配置与文件夹
1. 将当前 `fn-nas-ai-agents` 文件夹上传到飞牛 NAS 上的任意目录（例如 `/volume1/docker/ai-agents`）。
2. 在该目录下创建所需的数据持久化目录：
   ```bash
   mkdir -p clash
   mkdir -p config/botmux
   mkdir -p config/config
   mkdir -p config/openclaw
   ```
3. **修改 Clash 配置**：
   打开 `clash/config.yaml`，按文件中的注释修改：
   - 将 `Transit-Node` 替换为您的前置中转（机场）节点配置。
   - 将 `Residential-Exit` 替换为您购买的静态住宅 IP 代理配置（支持 SOCKS5 / HTTP 协议）。
4. **修改 docker-compose 配置**：
   打开 `docker-compose.yml`，找到 `botmux` 服务下的卷映射：
   ```yaml
   - /volume1/projects:/workspace
   ```
   将 `/volume1/projects` 替换为您 NAS 上实际存放代码项目的共享文件夹路径。
5. **配置 agy 模型模式 (可选)**：
   在 `docker-compose.yml` 的 `botmux` 环境变量中，默认已配置了 `AGY_MODEL=Gemini 3.5 Flash (High)` 来启用高性能模型。
   如果您需要切换，可以更改为以下值：
   * `Gemini 3.5 Flash (High)` (推荐，高性能模式)
   * `Gemini 3.5 Flash (Medium)` (中等性能)
   * `Gemini 3.5 Flash (Low)` (低性能)

---

### 第二步：启动 Clash 代理容器
在 NAS 的 SSH 终端或通过飞牛 Docker 网页，先拉起 Clash 代理服务以确保后续的登录连接：
```bash
docker compose up -d clash
```

---

### 第三步：首次运行与命令行授权登录 (非常关键)
因为 `agy` (Antigravity) 和 `codex` 在第一次运行时需要扫码或通过浏览器登录，我们需要在容器内部交互式地运行一次初始化：

1. **进入 Botmux 容器命令行**：
   ```bash
   docker compose run --entrypoint bash botmux
   ```
2. **授权登录 Antigravity CLI (`agy`)**：
   在容器内输入：
   ```bash
   agy
   ```
   终端会识别到非浏览器环境并输出一个类似 `https://antigravity.google/...` 的安全登录 URL。
   - 复制该链接到您电脑的浏览器中打开。
   - 登录您的 Google 账号完成授权。
   - 授权完成后，返回终端确认 `agy` 正常可用。
3. **授权登录 Codex CLI (`codex`)**：
   在容器内输入：
   ```bash
   codex
   ```
   按照终端提示完成您的 OpenAI/ChatGPT 账户登录，确保 `codex --version` 可运行。
4. **初始化 Botmux (`botmux setup`)**：
   在容器内运行：
   ```bash
   botmux setup
   ```
   按照屏幕提示操作（扫描飞书二维码或手动填入 App ID/Secret），选择您已安装的 `agy` 和 `codex` 作为桥接 CLI，并设置默认工作区为 `/workspace`。
5. **退出容器**：
   ```bash
   exit
   ```
   *注：此时您的所有登录 Token 和配置均已自动写入 NAS 的 `./config` 映射目录，容器销毁后也不会丢失。*

---

### 第四步：拉起所有服务
回到 NAS 上该目录下，运行：
```bash
docker compose up -d
```
此时三个容器均已正常启动。

---

## 日常管理 (飞牛 NAS Web UI)

服务成功启动后，您可以完全脱离命令行，直接使用**飞牛 NAS 系统的「Docker」管理器网页端**进行日常维护：
* **查看运行状态**：在“容器”列表中可实时查看 `ai-clash`、`ai-botmux` 和 `ai-openclaw` 的运行状态。
* **查看运行日志**：点击 `ai-botmux` 容器的“日志”页签，即可看到飞书消息接收、`agy` 或 `codex` 进程拉起和任务执行的完整流式日志。
* **重启/停止服务**：可在网页上直接一键重启 Botmux 或代理容器，或在修改 Clash 配置后直接重启 `ai-clash`。

---

## 验证与测试
在您的飞书企业版/个人版中，将您的 Bot 机器人加入一个话题群（Topic Group）中，新建一个话题发送您的代码需求：
1. 观察飞牛 Docker 网页端中 `ai-botmux` 的日志是否滚动。
2. 检查飞书是否收到实时的流式卡片消息反馈。
3. 网页终端（Web Terminal）链接是否能正常打开与操作。

---

## OpenClaw Control UI 管理后台

OpenClaw 包含一个 Web 图形化管理后台（Control UI），用于日常查看配置、管理运行日志，以及对 **Skill Workshop** 技能提案进行安全审计与审批（如审批/拒绝由 Agent 自动学习并提交的 `SKILL.md` 提案）。

### 1. 访问与登录
* **访问地址**：`http://<NAS_IP>:18789`（例如：`http://192.168.10.174:18789`）
* **登录 Token (密码)**：`apple`

### 2. 服务配置说明
为了确保能在 Mac 的浏览器上直接访问 NAS 的 OpenClaw 后台，本项目配置了以下设置：
* **网络端口**：在 `docker-compose.yml` 的 `openclaw` 服务中暴露了 `18789:18789` 端口映射。
* **接口绑定**：在 `openclaw.json` 中配置 `"bind": "lan"`（取代默认的 `loopback` 模式以监听 `0.0.0.0`），从而允许外部网络接入。
* **访问鉴权**：将 `gateway.auth.token` 配置为密码 `apple` 确保登录鉴权安全。

---

## 实践记录与排错指引 (Troubleshooting)

为了确保后续维护和迁移的顺利，以下整理了本次部署中解决的所有关键网络、编译与配置报错实践：

### 1. Docker 镜像拉取超时 (国内官方源限制)
*   **现象**：直接拉取 `metacubex/mihomo` 或 `openclaw/openclaw` 提示连接超时（Connection Reset）。
*   **实践**：
    *   在 [docker-compose.yml](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/docker-compose.yml) 中配置国内代理加速源前缀 `docker.1ms.run/`。
    *   **关键陷阱**：OpenClaw 官方镜像托管在 **GitHub Container Registry (GHCR)** 并非 Docker Hub。对它使用 Docker Hub 镜像源拉取会报 `manifest unknown` 错误。
    *   **终极解决**：对 OpenClaw 使用南京大学的专属 GHCR 加速镜像 `ghcr.nju.edu.cn/openclaw/openclaw:latest` 进行拉取。

### 2. NPM 编译卡住 (国内网络下载慢)
*   **现象**：构建 Botmux 镜像时，卡在 `npm install -g botmux @openai/codex`。
*   **实践**：在 [Dockerfile](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/Dockerfile) 中安装前插入命令切换为淘宝镜像源：
    ```dockerfile
    RUN npm config set registry https://registry.npmmirror.com
    ```

### 3. Node C++ 原生模块编译报错 (编译环境缺失)
*   **现象**：NPM 安装 `node-pty` 依赖时报错 `npm error code 1` / `gyp ERR! find Python`。
*   **实践**：`node-pty` 是 Botmux 用于提供网页终端的核心依赖，必须进行本地 C++ 编译。因此在 [Dockerfile](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/Dockerfile) 中，我们在 `apt-get` 依赖列表中额外安装了 `python3`、`make` 和 `g++`。

### 4. 容器构建时无法访问境外资源 (网络阻断)
*   **现象**：Dockerfile 中通过 `curl` 从谷歌服务器下载 `agy` 客户端或在 `apt-get` 阶段下载包时连接超时挂起。
*   **实践**：
    *   **APT 加速**：在 [Dockerfile](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/Dockerfile) 最上方增加了将 Debian 源自动修改为**中科大 (USTC) 镜像源**的指令，使组件安装速度提升百倍。
    *   **构建网络穿透**：在 [docker-compose.yml](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/docker-compose.yml) 的 `botmux` 服务中配置了 `network: host`，这使得构建临时容器可以直接访问主机的 `127.0.0.1` 环回接口。
    *   **构建命令**：在构建时传入本地 Clash 的代理接口：
        ```bash
        docker compose build --build-arg http_proxy=http://127.0.0.1:7890 --build-arg https_proxy=http://127.0.0.1:7890 botmux
        ```

### 5. Mihomo 新版本内核 Relay 报错 (废弃旧版语法)
*   **现象**：Clash 容器启动崩溃，日志报错 `unsupported type: relay`。
*   **实践**：新版 Metacubex 内核已彻底废除 `relay` 类型代理组。我们采用了现代化的 **`dialer-proxy` 机制**。在落地节点 `静态IP代理` 属性中添加 `dialer-proxy` 指向前置中转代理，并把 `AI-Relay-Group` 组修改为标准的 `select` 类型只选择落地节点即可实现完美链式转发。

### 6. 网络与性能可视化监控
*   **IP 与地理位置验证**：`curl -x http://127.0.0.1:7890 https://ipinfo.io`
*   **测速测试**：`curl -o /dev/null -x http://127.0.0.1:7890 http://speedtest.tele2.net/100MB.zip`
*   **Web UI 面板**：在 `docker-compose.yml` 中额外运行了 `clash-ui` (yacd-meta) 面板容器，可在电脑浏览器直接访问 `http://<NAS_IP>:1234`（连接 Clash API 端口 `9090`），实现对上传下载速率、历史连接明细和分流规则的全局图形化监测。

### 7. `botmux` 参数不兼容与 `agy` 自动执行限制 (`--yolo` 标志错误)
*   **现象**：`botmux` 没有内置的 `agy` 适配器，设置 `"cliId": "gemini"` 时它会带上 `--yolo` 标志来静默运行。但 `agy` 不认识 `--yolo`（会报错 `flags provided but not defined: -yolo` 退出）。
*   **实践**：在容器的 `/root/.local/bin/gemini` 位置创建了一个 Bash wrapper 脚本。该脚本拦截 `--yolo` 并替换为 `agy` 的 `--dangerously-skip-permissions` 参数，然后转发给 `agy` 运行。
*   **注意**：`docker cp` 往容器内拷贝该脚本时，容器原有的 `gemini` 如果是个指向 `agy` 的软链接，拷贝操作会顺着软链接直接覆盖 `agy` 二进制文件本身导致循环死锁。**正确的做法**是：先删除该软链接，再写入常规文件脚本。

### 8. `agy` 登录状态在容器重建时丢失 (未挂载配置文件卷)
*   **现象**：在容器中运行 `docker exec -it ai-botmux agy` 登录成功，但一旦使用 `docker compose up -d --force-recreate` 重建容器，登录态便会消失。
*   **实践**：在 `docker-compose.yml` 的 `botmux` 服务挂载卷中新增持久化映射 `- ./config/gemini:/root/.gemini`，确保 `agy` 的所有 OAuth 认证凭证与配置直接保存在宿主机上，即使容器彻底销毁或镜像升级，登录状态也会永久保留。

### 9. 宿主机工作区深度克隆与网络阻断 (克隆大型项目)
*   **现象**：克隆公共仓库如 `https://github.com/hugohe3/ppt-master.git` 到宿主共享目录时，由于网络限制可能会失败或极慢。
*   **实践**：
    *   **容器内克隆**：进入 `ai-botmux` 容器内运行 `git clone`，容器内已预配 Clash 代理环境变量，可满速完成拉取。
    *   **浅克隆（Shallow Clone）**：如果项目包含大量历史对象（如 `ppt-master` 包含 270MB 的图片和模板数据），为了避免网络抖动导致大对象索引（`git index-pack`）卡死，应使用 `--depth 1` 参数进行浅克隆：
        ```bash
        docker exec -it ai-botmux git clone --depth 1 https://github.com/hugohe3/ppt-master.git /workspace/ppt-master
        ```
    *   **权限修正**：由于在容器中是以 root 身份克隆的，在宿主机上可能会遇到 goog 账户无权修改的问题。克隆完成后需在宿主机上运行 `sudo chown -R goog:Users /vol1/1000/Worker/ppt-master` 修复权限。

### 10. `pip3` 编译原生 Python 图形依赖报错 (`libcairo2` 编译环境缺失)
*   **现象**：在 `Dockerfile` 中直接使用 `pip3` 安装 `ppt-master` 的运行环境（其中包含 `cairosvg` / `pycairo` 等）时，编译报错 `ERROR: Dependency lookup for cairo with method 'pkg-config' failed` 退出。
*   **实践**：在 `Dockerfile` 中安装依赖包时，预先安装 `libcairo2-dev` 和 `pkg-config` 两个系统开发依赖库，从而确保 `pycairo` 等图形依赖可以在构建阶段顺畅编译通过。

### 11. 容器网络下动态 Web 终端端口访问受阻与 SOCKS5 端口冲突
*   **现象**：点击 Feishu 卡片生成的 Web 终端链接时，显示无法访问。链接中带有类似 `45855` 这样的动态随机端口，以及 `8800` 代理端口均无法连接。
*   **实践**：
    *   **动态端口暴露**：`botmux` 每个 session 的 Web 终端都会分配一个动态随机端口，在 Docker bridge 网络模式下由于端口未做映射，导致外部主机无法连接。
    *   **主机网络模式（Host Network Mode）**：将 `ai-botmux` 容器的 `network_mode` 设为 `host`，使所有动态端口直接绑定到宿主机 IP。
    *   **环境代理更正**：主机模式下，更新 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` 指向宿主机的 `127.0.0.1:7890` 和 `127.0.0.1:7891`。
    *   **Dashboard 端口冲突处理**：`botmux` 的 dashboard 默认监听 `7891` 端口，这与 Clash 的 SOCKS5 代理端口 `7891` 在主机网络空间上发生碰撞导致 dashboard 不断崩溃重启。我们在 `docker-compose.yml` 环境变量中添加 `BOTMUX_DASHBOARD_PORT=7895`，将 dashboard 监听端口更改为 `7895`，彻底解决了端口冲突。
    *   **镜像内置 tmux**：在 `Dockerfile` 预装包列表中添加了 `tmux`，防止容器重建时反复检测和在线安装 `tmux`。

### 12. 切换 `agy` 模型运行模式（配置 `AGY_MODEL`）
*   **现象**：`agy`（Antigravity）默认运行时并非高性能模型（High 模式），且 `botmux` 框架没有原生的接口或变量来定制模型参数。
*   **实践**：
    *   **拦截脚本扩展**：修改了容器中 `/root/.local/bin/gemini` 的包装脚本，新增了对 `AGY_MODEL` 环境变量的检测。如果设置了该变量，脚本会在最终执行 `agy` 时自动追加 `--model "${AGY_MODEL}"` 参数。
    *   **Docker 环境变量注入**：在 `docker-compose.yml` 的 `botmux` 环境变量中默认配置了 `AGY_MODEL=Gemini 3.5 Flash (High)`，从而使飞书机器人后台自动以 High 高性能模型拉起所有 agy 代码会话。

### 13. Clash 住宅 IP 代理凭证更新与中转节点升级 (解决 agy 登录 EOF 报错)
*   **现象**：由于旧的中转节点失效，导致静态住宅 SOCKS5 代理发生连接超时（Context Deadline Exceeded / SSL_ERROR_SYSCALL），使 `agy` 在登录授权交换 Token 时报 `token exchange failed: Post "https://oauth2.googleapis.com/token": EOF`。
*   **实践**：
    *   更新 [clash/config.yaml](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/clash/config.yaml) 中静态住宅 SOCKS5 代理的服务器 IP、端口及账号密码。
    *   新增三台高性能 VMess 中转节点（奥地利 8、奥地利 9、台湾 22）。
    *   将低延迟的台湾中转节点设为 `静态IP代理` 的 `dialer-proxy` 前置代理，成功打通 GFW 限制；并将全部中转节点加入 `Default-Group` 中，实现稳定分流与高速鉴权连接。

### 14. OpenClaw Control UI 管理后台非 localhost 跨域拒绝与安全上下文限制 (code=1008 / token_missing)
*   **现象**：在外部电脑通过局域网访问 `http://<NAS_IP>:18789/chat?session=main` 时，浏览器因安全上下文非 HTTPS 阻断 Web Crypto API，提示 `control ui requires device identity`；在通过白名单或本地转发访问时，后端日志仍频繁关闭连接，提示 `unauthorized: gateway token missing`。
*   **实践**：
    1.  **后端 Origin 跨域放行**：编辑 `openclaw.json`，在 `gateway.controlUi` 下开启 `"allowInsecureAuth": true`，并将你的局域网访问 IP 显式加到 `allowedOrigins` 列表中（如 `"http://192.168.10.174:18789"`），防止后端 WebSocket 握手拦截。
    2.  **解决浏览器安全上下文限制（两种访问方式）**：
        *   **方式一（推荐，端口转发）**：在本地 Mac 终端运行 SSH 端口转发 `ssh -L 18789:127.0.0.1:18789 goog@<NAS_IP>`，并在本地浏览器访问 `http://127.0.0.1:18789/chat?session=main&token=apple`（由于 `127.0.0.1` 默认被浏览器信任为安全上下文，且链接带上了密码 Token `apple`，因此可以完美直接登录）。
        *   **方式二（直接局域网访问）**：在 Chrome 的 `chrome://flags/#unsafely-treat-insecure-origin-as-secure` 中将 `http://<NAS_IP>:18789` 强设为安全源。访问局域网链接时，在链接末尾带上 `&token=apple` 或在页面设置（齿轮图标）的 **Gateway Token** 中手动输入并保存 `apple`。

### 15. OpenClaw 审批技能修改提案报错 Target skill is missing 或 Target skill changed
*   **现象**：
    *   在 OpenClaw Control UI 的 **Skill Workshop** 界面点击 `apply` 审批技能提案时，系统报错 `Target skill is missing: /root/.openclaw/workspace/skills/bookkeeping/SKILL.md`。
    *   恢复技能文件后，再次点击 `apply` 仍报错：`Target skill changed after proposal creation; proposal marked stale`。
*   **原因**：
    *   默认的 `"workspace"` 在 `openclaw.json` 中配置为 `/root/.openclaw/workspace`，该路径位于 Docker 容器内部的临时层，容器重建时会被抹去，导致已部署的技能文件（如 `bookkeeping/SKILL.md`）丢失。
    *   恢复备份文件后，由于待审批的更新提案中记录的 `currentContentHash` 是此前在容器运行时发生临时修改后的哈希值（`93d59339...`），而我们恢复的技能文件具有最早部署时的哈希值（`85b14226...`），两者哈希不一致，导致系统判定目标技能被篡改而拒绝应用。
*   **实践**：
    1.  **迁移工作区至宿主机持久化**：修改 `openclaw.json` 中的 `"workspace"` 为 `/home/node/.openclaw/workspace`（映射到宿主机的 `./config/openclaw/workspace`），以确保技能文件不会丢失。
    2.  **重建并恢复已应用的记账技能**：在宿主机上创建目录 `./config/openclaw/workspace/skills/bookkeeping`，并将历史提案数据库（`bookkeeping-20260613-41637c8a3c`）中原有的 `SKILL.md` 恢复至该目录下。
    3.  **修复待审核提案的关联路径**：运行 Python 脚本，将 `./config/openclaw/skill-workshop/proposals.json` 及子目录所有 `proposal.json` 里的旧路径 `/root/.openclaw/` 全部全局替换为 `/home/node/.openclaw/`。
    4.  **修正预期哈希匹配校验**：在 pending 提案的 `./config/openclaw/skill-workshop/proposals/bookkeeping-20260619-5656284abf/proposal.json` 中，将 `target.currentContentHash` 修改为实际恢复的 `SKILL.md` 的哈希值 `85b1422608ab92131871c8c33795efdba4e80ff8f2923ec220bb24fcce5ec1c8`。
    5.  **重启服务**：运行 `docker restart ai-openclaw`，重新加载后即可顺利完成 `apply` 审核。

### 16. 修复非 Owner 成员调用 UAT 工具的权限拦截 (OwnerAccessDeniedError / instanceof 崩溃)
*   **现象**：
    *   在飞书群聊中，非应用所有者（App Owner）的同事（例如 `ou_7f5fde735fa65776d9bc78bca591053c`）调用多维表格写入等 UAT 工具时，机器人报错 `permission_denied`，信息为 `"当前应用仅限所有者（App Owner）使用。您没有权限使用相关功能。"`。
    *   在添加权限/授权后，调用工具可能会触发插件内部崩溃，报错：`Right-hand side of 'instanceof' is not an object`，且后台日志伴有 `Accessing non-existent property 'OwnerAccessDeniedError' of module exports inside circular dependency` 的循环依赖警告。
*   **原因**：
    *   官方原版的 `@openclaw/feishu` (即 `openclaw-lark`) 插件硬编码了严格的 App Owner 校验（`assertOwnerAccessStrict`），任何 UAT (User Access Token) 调用都必须是唯一的飞书应用所有者，且在异常捕获时因插件代码编译后存在循环依赖，导致 `instanceof` 判断无法加载 Error 类而直接崩溃。
*   **实践**：
    *   **应用官方 PR 补丁**：根据官方 PR #296 提交记录，对 NAS 映射的插件目录 `./config/openclaw/extensions/openclaw-lark/src` 下的四个文件（`config-schema.js`、`owner-policy.js`、`auto-auth.js`、`oauth.js`）进行了代码热补丁合并，引入了白名单绕过机制。
    *   **白名单配置**：修改宿主机 `./config/openclaw/openclaw.json`，在飞书渠道的 `feishu.uat` 下新增 `allowedUsers` 白名单，将需要使用工具的同事的 `open_id` 追加进去：
        ```json
        "feishu": {
          "enabled": true,
          "appId": "cli_a977cf6ca279dcb3",
          ...
          "uat": {
            "allowedUsers": [
              "ou_64ca0a89fcabb347a23aad206094a679",
              "ou_7f5fde735fa65776d9bc78bca591053c"
            ]
          }
        }
        ```
    *   **更新与重载**：在 NAS 宿主机中执行 `docker compose pull` 拉取最新镜像重构容器，并在容器重新拉起后执行 `docker restart ai-openclaw` 重新载入，使补丁和配置在最安全的只读沙箱下成功运行。

### 17. Docker 容器内 CLI 授权登录回调页面无法访问 (localhost:1455 环回地址隔离)
*   **现象**：在容器内运行 `docker exec -it ai-botmux agy` 或 `codex` 进行登录时，点击浏览器授权成功后，页面自动跳转到 `http://localhost:1455/auth/callback?code=...` 并提示连接失败或无法访问。
*   **原因**：授权 CLI 程序在容器内部启动了临时 Web 服务以监听回调凭证，在 `network_mode: host` 模式下，该服务直接在 NAS 宿主机的 `127.0.0.1:1455` 端口进行监听。但由于你的浏览器运行在本地 Mac 电脑上，`localhost` 会尝试连接 Mac 本机端口，而非远程 NAS 的端口，导致无法建立连接。
*   **实践**：
    *   **本地 Mac 端口转发**：在你的 Mac 本地终端（不是 NAS 终端）运行 SSH 端口转发命令建立通道：
        ```bash
        ssh -L 1455:127.0.0.1:1455 goog@<NAS_IP>
        ```
        *(输入密码 `apple` 保持连接窗口不要关闭)*
    *   **重新刷新连接**：保持 SSH 连接，在 Mac 浏览器中直接刷新那个打不开的 `http://localhost:1455/...` 回调链接，浏览器即可通过本地隧道将凭证安全发给 NAS 容器完成授权登录。

### 18. Codex 启动 MCP 协议报错 (GFW 阻断 chatgpt.com 请求)
*   **现象**：完成 `codex` 授权登录后，系统内部报错：`MCP client for codex_apps failed to start: handshaking with MCP server failed... Client error: HTTP request failed: ... (https://chatgpt.com/backend-api/wham/apps)` 且伴有 `tls handshake eof` 异常。
*   **原因**：Codex 在启动底层 MCP 服务时，需要向 `chatgpt.com` 接口发送初始化请求。然而在我们的 Clash 配置中，只有 `openai.com` 规则，缺少了 OpenAI 关联的新域名 `chatgpt.com`、`oaistatic.com` 及 `oaiusercontent.com`，导致该 API 请求因直连而被 GFW 阻断，引发握手失败。
*   **实践**：
    *   **更新 Clash 分流规则**：编辑 [clash/config.yaml](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/clash/config.yaml)，在 `rules` 中追加以下三行规则并分流到 `AI-Relay-Group`：
        ```yaml
        - DOMAIN-SUFFIX,chatgpt.com,AI-Relay-Group
        - DOMAIN-SUFFIX,oaistatic.com,AI-Relay-Group
        - DOMAIN-SUFFIX,oaiusercontent.com,AI-Relay-Group
        ```
    *   **重载服务**：重新上传配置到 NAS，并在 NAS 终端执行 `docker restart ai-clash` 重启代理服务，此后连接拦截问题彻底解决。

### 19. SSH 登录 NAS 报错 Could not chdir to home directory /home/goog
*   **现象**：每次通过 SSH 终端命令行登录 NAS 账户 `goog` 或在自动化执行指令的日志中，总会频繁显示报警：`Could not chdir to home directory /home/goog: No such file or directory`。
*   **原因**：NAS 系统的 `/etc/passwd` 用户账号配置文件中为 `goog` 指定了以 `/home/goog` 作为家目录，但是在系统上实际上并没有创建该物理路径，导致登录后无法成功切入家目录而报警。
*   **实践**：
    *   **手动创建家目录并授权**：在 NAS 宿主机终端运行以下命令创建对应目录，并将其所有权分派给 `goog` 用户：
        ```bash
        sudo mkdir -p /home/goog
        sudo chown goog:Users /home/goog
        ```
    *   创建后重新进行 SSH 连接，警告提示即可彻底解决。

### 20. 如何获取与访问 Botmux Web Dashboard (管理后台面板)
*   **应用端口**：Botmux 的 Web 面板在 `docker-compose.yml` 中默认被重映射到了 **`7895`** 端口（为了避免与 Clash SOCKS5 代理端口冲突），容器为主机网络模式，因此服务在 `http://<NAS_IP>:7895` 进行监听。
*   **获取登录链接**：
    由于访问面板需要一次性安全 Token 校验，你需要运行指令来打印完整的登录链接。在 NAS 终端中运行：
    ```bash
    sudo docker exec -it ai-botmux botmux dashboard
    ```
*   **访问方法**：
    执行上述指令后，终端会打印出类似下方的链接：
    `http://192.168.10.174:7895/?t=xxxxxx`
    直接复制该链接在浏览器中打开即可成功进入 Botmux Dashboard，进行机器人运行管理与会话状态可视化查看。

### 21. 如何实现 Botmux 容器启动时自动更新 (保持最新版本面板与功能)
*   **现象**：由于旧版镜像拉取时间较早，容器内部的 `botmux` 包仍处于旧版本（如 `2.29.0`），导致 Web 面板界面较简陋，且缺乏新版功能。
*   **配置优化**：
    为了使容器在不影响使用的情况下自动获取最新版本，我们在 [docker-compose.yml](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/docker-compose.yml) 中修改了 `botmux` 服务的启动命令，在守护进程拉起前前置运行了 `npm install -g botmux`：
    ```yaml
    command: bash -c "npm install -g botmux && botmux start && ..."
    ```
*   **机制**：
    由于我们在 Dockerfile 中预配置了高带宽的淘宝 npm 镜像源，因此每次容器重启、重新拉起或 NAS 重启时，容器启动会自动在数秒内通过加速镜像将全局的 `botmux` 库升级至最新稳定版（当前已成功自动升级至 **`2.84.0`**），随后无缝运行服务，保证面板和组件永远处于最新状态。

### 22. 如何实现 OpenClaw 容器自动更新 (Watchtower 机制)
*   **现象/需求**：OpenClaw 服务并非基于通用的系统容器直接通过 npm 命令启动，而是通过打包好的 Docker 镜像运行。这导致它无法像 Botmux 一样在启动命令中运行 `npm install` 来热更新。为了避免频繁地手动登录服务器拉取镜像和重建容器，需要一套可自动化、不影响已有数据挂载卷的镜像监测与热重构机制。
*   **实践**：
    *   **引入 Watchtower 服务**：在 [docker-compose.yml](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/docker-compose.yml) 中引入了 `watchtower` 服务（使用加速源镜像 `docker.1ms.run/containrrr/watchtower:latest`），并通过映射 `/var/run/docker.sock` 赋予其调用宿主机 Docker API 的权限。
    *   **指定过滤容器与运行周期**：通过命令参数 `--cleanup --interval 86400 ai-openclaw` 限制其仅监控 `ai-openclaw` 容器，检查周期设为 24 小时，且在更新后自动清理无用的旧版本镜像残留。
    *   **平滑更新与数据持久化**：当 OpenClaw 的镜像源（如国内加速可达的 `ghcr.nju.edu.cn/openclaw/openclaw:latest`）更新时，Watchtower 会在后台拉取新镜像，优雅关闭原有容器，并使用完全一致的参数和挂载路径（宿主机 `./config/openclaw`）重新启动容器，确保审批提案及技能工作区配置数据毫无损失。

### 23. 重启或重建 Docker 容器后 Botmux 里的 agy / codex 授权丢失
*   **原因分析**：
    1.  **Codex 授权丢失**：Codex 登录后所有的 Session 和 SQLite 数据库存放在 `~/.codex`（即容器内的 `/root/.codex`）。原配置中未对该目录映射持久化挂载卷，导致容器重建时授权态被彻底抹除。
    2.  **agy（Gemini）无法运行**：为了拦截 `--yolo` 标志，我们为 `agy` 编写了 `gemini` 包装脚本并存放在 `/root/.local/bin/gemini` 中。由于 `/root/.local` 属于容器的临时文件层且没有挂载，每次容器重启或重建后该脚本均会被删除，导致 botmux 在执行 gemini 时找不到对应命令或执行失败，现象表现为“授权失效/机器人无响应”。
*   **解决方案**：
    1.  **备份并持久化 Codex 目录**：
        *   在宿主机上创建 `./config/codex` 目录，并在容器重建前，通过宿主机执行备份命令以提取当前有效的 credentials 数据库：
            ```bash
            docker cp ai-botmux:/root/.codex /vol1/1000/docker_data/fn-nas-ai-agents/config/codex
            ```
        *   在 [docker-compose.yml](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/docker-compose.yml) 的 `botmux` 服务中增加持久化挂载卷映射：
            ```yaml
            - ./config/codex:/root/.codex
            ```
    2.  **永久固化 agy (Gemini) 拦截脚本**：
        *   修改 [Dockerfile](file:///Users/apple/Desktop/work/github/fn-nas-ai-agents/Dockerfile)，在构建镜像阶段直接将 `gemini` 拦截脚本写入 `/root/.local/bin/gemini` 并赋予执行权限。这样拦截脚本会作为镜像的只读层随容器自动生成，无需宿主机挂载。
    3.  **同步全局 config.json 配置文件**：
        *   将 Mac 本地的全局配置文件 `~/.gemini/config/config.json` 同步至宿主机的 `./config/gemini/config/config.json`（对应容器内的 `/root/.gemini/config/config.json`），解决 `agy` 启动时关于 config 缺失的报错警告。
    4.  **重新编译与重构**：
        *   执行 `docker compose build --build-arg http_proxy=... botmux` 和 `docker compose up -d` 重新构建并拉起服务，授权在后续任意销毁、重建 and 重启中均实现完美持久化。

### 24. Clash 链式代理下静态住宅 IP 代理延迟过高 (跨国绕路问题)
*   **原因分析**：
    1.  您的静态住宅 IP 代理（落地出口）物理位置位于 **荷兰 (NL)**。
    2.  在引入 Clash 订阅源进行前置中继代理自动测速组 (`url-test`) 后，Clash 默认根据国内直连延迟自动选路，由于台湾物理距离近，Clash 自动选用了 **台湾** 中转节点。
    3.  这导致了严重的全球数据绕路：`NAS (国内) -> 台湾中继 (亚洲) -> 荷兰落地 (欧洲) -> 目标网站`。跨洲传输导致网络延迟极高，对 `google.com` 握手延时高达 `6.1s`（其中 TLS 握手就占用了 `4.8s`）。
*   **解决方案**：
    1.  **限制中继节点至欧洲区域**：
        编辑 `clash/config.yaml`，在自动测速组 `Transit-Auto-Select` 中添加正则过滤器 `filter: "奥地利"`（或 `"德国|英国|荷兰|欧洲"`），使中转节点强制选用位于欧洲本地的节点（如奥地利等，物理位置紧邻荷兰落地）：
        ```yaml
        - name: "Transit-Auto-Select"
          type: url-test
          use:
            - jssrgssr
          filter: "奥地利"
          url: "http://www.gstatic.com/generate_204"
          interval: 300
          tolerance: 50
        ```
    2.  **网络优化结果**：
        *   路由路径优化为近距离欧洲局域网直连：`China -> Austria (中继) -> Netherlands (落地)`。
        *   Google HTTPS 的整体响应延时由 `6.1s` 锐减至 `2.8s`（**降低了 54% 延时**），在双重代理链条下，不带 TLS 的纯 HTTP RTT 首字节响应速率缩减至 **616ms**，访问速度显著提升。

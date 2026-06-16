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



# CCPCOJ 部署（比赛系统）

本文说明如何用部署工具 `csgoj-deploy` 部署 **XCPC 比赛系统**：先部署 Web（含 MySQL、Nginx、phpMyAdmin），在网页里完成初始化并创建评测机账号，再部署评测机。

- 运行模式固定为 `cpcsys`（比赛系统）、状态 `cpc`。
- Web 与评测机可以同机，也可以分开；评测机机器同样使用 `csgoj-deploy`。
- 下文命令都在 Linux 终端中执行，`mycpc`、端口、口令请换成你自己的。

## 1. 部署前准备

### 1.1 机器要求

| 项目 | 要求 |
| --- | --- |
| 系统 | Ubuntu 22.04 / 24.04 / 26.04（x86_64） |
| 内核 | 评测机需要 5.19 以上（Ubuntu 24.04 起自带；22.04 见下） |
| CPU / 内存 | 每个评测容器使用 4 核 4GB（另有 1GB 共享内存）。单机试用 4 核 8GB 起；正式比赛按评测容器数量配机器 |
| 网络 | 能访问腾讯云镜像仓库或 Docker Hub；评测机要能访问 Web 的地址和端口 |

Ubuntu 22.04 若仍是 5.15 内核，先升级 HWE 内核再部署评测机：

```bash
sudo apt-get update
sudo apt-get install -y linux-generic-hwe-22.04
sudo reboot
```

### 1.2 安装 Docker

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo docker info
```

`docker info` 能输出服务端信息即可。下文命令都用 `sudo` 执行；如想不加 `sudo`，执行 `sudo usermod -aG docker $USER` 后重新登录。

### 1.3 下载部署工具

到本仓库 [Releases](https://github.com/SZTU-ACM/CCPCOJ-2/releases) 下载 Linux x86_64 的 `csgoj-deploy`：

```bash
mkdir -p ~/csgoj && cd ~/csgoj
# 把 <版本号> 换成 Releases 页面上的版本，例如 2.0.268
wget -O csgoj-deploy https://github.com/SZTU-ACM/CCPCOJ-2/releases/download/<版本号>/csgoj-deploy_<版本号>_linux_amd64
chmod +x csgoj-deploy
./csgoj-deploy version
```

无法直接访问 GitHub 时，可在别的电脑下载后用 `scp` 传到服务器。

### 1.4 镜像从哪里来

部署工具自动拉取镜像，**先试腾讯云公开仓库**，不可用时再用 Docker Hub：

| 用途 | Docker Hub | 腾讯云 |
| --- | --- | --- |
| Web | `csgrandeur/ccpcoj-web2:<版本>` | `ccr.ccs.tencentyun.com/csgrandeur/ccpcoj-web2:<版本>` |
| 评测机 | `csgrandeur/ccpcoj-judge2:<版本>` | `ccr.ccs.tencentyun.com/csgrandeur/ccpcoj-judge2:<版本>` |

MySQL、Nginx、Redis、phpMyAdmin 等依赖镜像同样按这个顺序拉取。`--csgoj-version` 不写时用 `latest`；正式比赛建议写明版本号，Web 与评测机用同一个版本。

## 2. 部署 Web

```bash
cd ~/csgoj
sudo ./csgoj-deploy up --noninteractive \
    --path-data /csgoj_data \
    --nginx-ranges 20000-20099 \
    --site mycpc:20080:cpcsys:cpc \
    --port-myadmin 20050 \
    --port-db 0 \
    --sql-root '<MySQL-root-口令>' \
    --sql-user-pass '<MySQL-业务口令>' \
    --myadmin-pass '<phpMyAdmin-页面口令>' \
    --csgoj-version latest
```

参数含义：

| 参数 | 说明 |
| --- | --- |
| `--path-data` | 数据目录（绝对路径）。数据库、题目数据、日志都在这里，备份与迁移对着它操作 |
| `--nginx-ranges` | Nginx 对外开放的端口段。站点端口和 phpMyAdmin 端口都要落在段内 |
| `--site` | 站点，格式 `名称:端口:cpcsys:cpc`。名称只用字母数字，会成为容器名 `php-名称` |
| `--port-myadmin` | phpMyAdmin 端口 |
| `--port-db` | MySQL 在宿主机上的端口；`0` 表示不对外开放（推荐） |
| `--sql-root` / `--sql-user-pass` / `--myadmin-pass` | 口令，**必须自己设置**，建议只用字母和数字 |
| `--csgoj-version` | 镜像版本，默认 `latest` |

首次部署要拉取镜像，耗时取决于网络。完成后用浏览器打开：

```text
http://<服务器IP或域名>:20080
```

若无法打开，检查云服务器安全组 / 防火墙是否放行了该端口。

首次启动时 Web 容器要把静态文件（样式、图标、脚本）初始化到数据目录，配置较低的机器上大约需要一分钟；这段时间页面可能缺样式或图标，稍等刷新即可。

### 2.1 网页初始化

首次打开页面会进入初始化向导：

1. 设置**系统管理员**账号和口令（用户名 5–20 位字母、数字或下划线），点「初始化系统」，在提示框点「确定」；
2. 页面跳转到「评测机管理」（之后也可从 管理后台 → 评测机 进入）。在「评测机列表」上方填好评测机口令和账号前缀，点旁边的添加按钮，列表里会出现新账号。

![评测机管理](deploy_doc_image/judger.png)

## 3. 部署评测机

在「评测机管理」列表中，**双击**该评测机那一行的连接状态图标（或单击图标打开登录日志，再点里面的「复制部署命令」按钮），部署命令会复制到剪贴板，类似：

```bash
sudo ./csgoj-deploy judge \
    --server-url http://<Web服务器IP或域名>:20080 \
    --username <评测机账号> \
    --password '<评测机口令>' \
    --oj-name <评测机账号> \
    --pods 1
```

到评测机器上（可以就是 Web 服务器），进入放 `csgoj-deploy` 的目录（如 `~/csgoj`）粘贴执行。注意：

- `--server-url` 必须是评测机能访问到的地址。复制出来的是你浏览器里的地址；若浏览器用的是 `localhost` / `127.0.0.1`，请改成服务器的局域网 IP 或域名（工具会拒绝 localhost）。
- Web 指定了版本时，在命令末尾加同样的 `--csgoj-version <版本>`。
- `--pods` 是评测容器数量，每个占 4 核 4GB（外加 1GB 共享内存），工具会按机器 CPU 自动绑核；机器不够时会提示最多能开几个。内存不足 4GB 的机器工具会直接拒绝，这时把评测机放到另一台机器上即可（Web 与评测机可以分开部署）。

几十秒后回到「评测机管理」，评测机状态变为在线即可。

## 4. 部署后检查

```bash
sudo docker ps
```

Web 侧容器：`db`、`csgoj-redis`、`myadmin`、`nginx-server`、`php-mycpc`；评测机：`judge-<名称>`，多个时为 `judge-<名称>-1`、`judge-<名称>-2` …

查看日志：

```bash
sudo docker logs php-mycpc
sudo docker logs nginx-server
sudo docker logs -f judge-<名称>
```

评测机文件日志在 `/csgoj_data/var/log/judger/`。

最后走一遍办赛流程确认评测正常（具体操作见用户文档）：

1. 管理后台 → 题目 → 添加题目，保存后在该题的「评测数据」里上传 `1.in` / `1.out`；
2. 管理后台 → 比赛 → 添加比赛，填好时间并加入这道题；新建的比赛默认是**隐藏**的，要在比赛列表里把状态切到「公开」，否则队伍登录会提示 “You cannot open this contest.”；
3. 在比赛管理里生成队伍账号，用队伍账号登录比赛提交，确认返回评测结果、榜单正常显示。

## 5. 常用操作

```bash
./csgoj-deploy help                                # 全部参数
sudo ./csgoj-deploy judge --oj-name <名称> --restart-all   # 重启评测机
sudo ./csgoj-deploy judge --oj-name <名称> --remove-all    # 删除评测机容器（数据保留）
```

- **重建评测机**：先 `--remove-all`，再执行一次第 3 节复制得到的命令。
- **升级 Web**：用新的 `--csgoj-version` 重新执行第 2 节命令。工具发现镜像变了会重建 `php-名称` 容器并刷新静态文件，数据目录不变，数据保留。
- **升级评测机**：先 `--remove-all`，再把第 3 节命令里的 `--csgoj-version` 换成新版本执行。
- **增加评测容器**：把 `--pods` 改大后重新执行部署命令，已有容器保留，只补启动缺的。
- **再开一个站点**：在第 2 节命令里多写一个 `--site 名称2:20081:cpcsys:cpc`（端口在 `--nginx-ranges` 段内）重新执行。

## 6. 常见问题

**评测机一直不在线**：`sudo docker logs judge-<名称>` 看报错。多数是 `--server-url` 不可达（用了 localhost、端口没放行）或账号口令不对。

**端口冲突**：`ss -tuln | grep -E '20080|20050'` 查占用，换端口重新部署。

**提示内核低于 5.19 / 未启用 cgroup v2**：按 1.1 升级内核并重启。

**镜像拉取失败**：确认机器能访问 `ccr.ccs.tencentyun.com` 或 Docker Hub；镜像已在本地时工具不会重复拉取。

**docker 权限错误**：命令前加 `sudo`，或按 1.2 把用户加入 docker 组后重新登录。

## 7. 正式上线检查

- [ ] 数据目录固定（如 `/csgoj_data`），磁盘空间充足，有备份安排
- [ ] 口令都已自行设置；MySQL 端口未对外开放（`--port-db 0`）
- [ ] 已设置管理员与评测机账号
- [ ] 评测机的 `--server-url` 不是 localhost，评测机显示在线
- [ ] `sudo docker ps` 中 Web 与评测机容器都在运行
- [ ] 提交一道题能正常返回结果，榜单正常
- [ ] 保存好本次使用的部署命令（含版本号）

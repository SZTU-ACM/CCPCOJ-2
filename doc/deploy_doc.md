# CSGOJ 一键部署

用 `csgoj_deploy.sh` 部署。第一个参数指定类型：

- `web`：Web 服务（MySQL、Nginx、PHP、phpMyAdmin）
- `judge`：评测机

先部署 Web，在后台配好评测机账号后，再部署 Judge。

## 1. 部署前准备

### 1.1 环境

- 系统：Ubuntu 22.04 或更高。Judge 节点脚本会检查系统版本。
- Ubuntu 22.04 若仍是 5.15 内核，Judge 可能起不来，先把 HWE 内核升到 5.19 以上：

```bash
sudo apt-get update
sudo apt-get install -y linux-generic-hwe-22.04
sudo reboot
```

- Web 节点会自动装 Docker；已经装过则直接用现有环境。
- 当前用户需要 `sudo`。
- 服务器要能拉到 Docker 镜像。

### 1.2 准备脚本

把发布包里的脚本放到服务器，例如：

```bash
mkdir -p /opt/csgoj
cd /opt/csgoj
# 将 csgoj_deploy.sh 上传到此目录
chmod +x csgoj_deploy.sh
```

数据目录用固定绝对路径，例如 `/csgoj_data`。备份、迁移、排障都对着这个目录做。

## 2. 部署步骤

### 2.1 部署 Web

正式环境把参数写全：

```bash
PORT_OJ=20080
PORT_MYADMIN=20050
PATH_DATA=/csgoj_data
OJ_NAME=hbcpc

bash csgoj_deploy.sh web \
    --noninteractive \
    --PATH_DATA="$PATH_DATA" \
    --OJ_NAME="$OJ_NAME" \
    --OJ_MODE=cpcsys \
    --PORT_OJ="$PORT_OJ" \
    --PORT_MYADMIN="$PORT_MYADMIN" \
    --PORT_DB=20006 \
    --PASS_SQL_ROOT="<MySQL-root-密码>" \
    --PASS_SQL_USER="<MySQL-业务用户密码>" \
    --PASS_MYADMIN_PAGE="<phpMyAdmin-页面密码>"
```

本地试跑可以用脚本默认值。不交互部署时加 `--noninteractive`：

```bash
bash csgoj_deploy.sh web
bash csgoj_deploy.sh web --noninteractive
```

首次运行且未加 `--noninteractive` 时，脚本会交互询问配置。完成后访问：

```text
http://<服务器IP或域名>:20080
```

第一次打开页面会引导设置：

- 系统管理员账号
- 评测机账号和密码

评测机账号设好后，到 Web 后台复制评测机部署命令（或参数），用来部署 Judge。

### 2.2 部署评测机

评测机可以和 Web 同机，也可以另开机器。`CSGOJ_SERVER_BASE_URL` 必须是评测机**容器内**能访问到的 Web 地址，不要写 `localhost` 或 `127.0.0.1`。

```bash
bash csgoj_deploy.sh judge \
    --OJ_NAME=hbcpc \
    --PATH_DATA=/csgoj_data \
    --CSGOJ_SERVER_BASE_URL=http://<Web服务器IP或域名>:20080 \
    --CSGOJ_SERVER_USERNAME=<评测机账号> \
    --CSGOJ_SERVER_PASSWORD=<评测机密码> \
    --JUDGE_POD_COUNT=1
```

临时绑核可以加：

```bash
--CPUSET_CPUS=0-3
```

`CPUSET_CPUS` 会让所有评测机 pod 用同一段 CPU，只适合试跑或单 pod。多 pod 正式部署让脚本自己分配即可。

后台双击评测机配置，可以复制启动脚本：

![image](https://docimg1.docs.qq.com/image/AgAABTXOtMPQOJfht0dCaYP65rtP9Cht.png?w=597&h=582)

## 3. 部署后检查

### 3.1 查看容器

```bash
docker ps
```

Web 部署成功后一般会有：

- `db`
- `myadmin`
- `php-<OJ_NAME>`
- `nginx-server`

Judge 部署成功后一般会有：

- 单 pod：`judge-<OJ_NAME>`
- 多 pod：`judge-<OJ_NAME>-0`、`judge-<OJ_NAME>-1` 等

### 3.2 查看日志

Web：

```bash
docker logs php-hbcpc
docker logs nginx-server
docker logs db
```

评测机：

```bash
docker logs -f judge-hbcpc
```

评测机文件日志在：

```text
/csgoj_data/var/log/judger/
```

`OJ_NAME` 不是 `hbcpc` 时，把命令里的 `hbcpc` 换成实际名称。

## 4. 常用参数

### 4.1 Web 参数

| 参数 | 说明 | 默认值 |
| --- | --- | --- |
| `--PATH_DATA` | 数据目录，必须是绝对路径 | `$(pwd)/data/csgoj_data` |
| `--OJ_NAME` | OJ 实例名，同时影响容器名 | `ccpc` |
| `--OJ_MODE` | OJ 模式，比赛系统用 `cpcsys` | `cpcsys` |
| `--PORT_OJ` | Web 端口 | `20080` |
| `--PORT_MYADMIN` | phpMyAdmin 端口 | `20050` |
| `--PORT_DB` | MySQL 映射到宿主机的端口 | `20006` |
| `--PASS_SQL_ROOT` | MySQL root 密码 | `987654321` |
| `--PASS_SQL_USER` | MySQL 业务用户密码 | `987654321` |
| `--PASS_MYADMIN_PAGE` | phpMyAdmin 页面密码 | `987654321` |
| `--CSGOJ_VERSION` | Docker 镜像版本 | `latest` |
| `--DOCKER_PULL_NEW` | 是否拉新镜像，断网可设 `0` | `1` |

正式环境不要用默认密码。密码尽量只用数字和英文字母，避免在 shell、配置文件、容器环境变量里被转义。

### 4.2 Judge 参数

| 参数 | 说明 | 是否必填 |
| --- | --- | --- |
| `--CSGOJ_SERVER_BASE_URL` | Web 地址，评测机容器必须能访问 | 是 |
| `--CSGOJ_SERVER_USERNAME` | 评测机账号 | 是 |
| `--CSGOJ_SERVER_PASSWORD` | 评测机密码 | 是 |
| `--JUDGE_POD_COUNT` | 评测机 pod 数量 | 否，默认 `1` |
| `--PATH_DATA` | 评测机数据目录 | 否 |
| `--OJ_NAME` | OJ 实例名 | 否 |
| `--CPUSET_CPUS` | 强制 CPU 绑核范围 | 否 |
| `--restart-all` | 重启现有评测机容器 | 否 |
| `--rebuild-all` | 删除并重建评测机容器，需提供连接参数 | 否 |
| `--remove-all` / `--delete-all` | 删除评测机容器，不重建 | 否 |

脚本会按机器资源给每个 pod 分配 CPU 和内存。一般每个 pod 大约 4 个逻辑核、4GB 内存、1GB SHM。资源不够时会提示最多能起几个 pod。

## 5. Nginx 额外端口映射

默认只映射 OJ Web 端口和 phpMyAdmin 端口。

要给 Nginx 加自定义端口，用：

```bash
--NGINX_PORT_RANGES="-p 50030-50189:50030-50189"
```

这个参数会原样传给 Nginx 容器的 `docker run`。设了之后**只使用你写的映射**，OJ 和 phpMyAdmin 端口如果还要保留，得一起写进去：

```bash
--NGINX_PORT_RANGES="-p 20080:20080 -p 20050:20050 -p 50030-50189:50030-50189"
```

完整示例：

```bash
bash csgoj_deploy.sh web \
    --noninteractive \
    --PATH_DATA=/csgoj_data \
    --OJ_NAME=hbcpc \
    --PORT_OJ=20080 \
    --PORT_MYADMIN=20050 \
    --NGINX_PORT_RANGES="-p 20080:20080 -p 20050:20050 -p 50030-50189:50030-50189" \
    --PASS_SQL_ROOT="<MySQL-root-密码>" \
    --PASS_SQL_USER="<MySQL-业务用户密码>" \
    --PASS_MYADMIN_PAGE="<phpMyAdmin-页面密码>"
```

## 6. 配置文件与重复运行

部署完成后配置写在：

```text
./data/csgoj_config.cfg
```

再次运行时：

- 不传参数：用已有配置文件
- 传了命令行参数：命令行覆盖配置文件
- `--ignore-config`：不用默认配置文件
- `--CONFIG_FILE=<文件>`：指定另一份配置

优先级：

```text
命令行参数 > 指定配置文件 > 默认配置文件 > 脚本默认值
```

实际用过的部署命令和 `./data/csgoj_config.cfg` 留一份，方便以后对照。

## 7. 常用操作

### 7.1 查看帮助

```bash
bash csgoj_deploy.sh --help
```

当前 release 的 `--help` 可能只列出评测机相关项。Web 参数以本文和脚本里的默认值为准。

### 7.2 重启评测机

```bash
bash csgoj_deploy.sh judge --OJ_NAME=hbcpc --restart-all
```

### 7.3 删除并重建评测机

```bash
bash csgoj_deploy.sh judge \
    --OJ_NAME=hbcpc \
    --PATH_DATA=/csgoj_data \
    --CSGOJ_SERVER_BASE_URL=http://<Web服务器IP或域名>:20080 \
    --CSGOJ_SERVER_USERNAME=<评测机账号> \
    --CSGOJ_SERVER_PASSWORD=<评测机密码> \
    --rebuild-all
```

### 7.4 删除评测机容器

```bash
bash csgoj_deploy.sh judge --OJ_NAME=hbcpc --remove-all
```

## 8. 常见问题

### 8.1 评测机连不上 Web

先查 `CSGOJ_SERVER_BASE_URL`：

- 不要用 `localhost`
- 不要用 `127.0.0.1`
- Web 和 Judge 在同一台机器，也要用服务器内网 IP 或外网 IP
- 防火墙、安全组、Nginx 端口映射都要放行

### 8.2 端口冲突

看端口是否被占：

```bash
netstat -tuln | grep 20080
netstat -tuln | grep 20050
```

换端口后重新部署 Web：

```bash
bash csgoj_deploy.sh web \
    --PATH_DATA=/csgoj_data \
    --OJ_NAME=hbcpc \
    --PORT_OJ=8080 \
    --PORT_MYADMIN=8050
```

### 8.3 Docker 权限

脚本会尝试把当前用户加入 `docker` 组。如果提示当前终端还不能直接跑 Docker，重新登录一次，或先执行：

```bash
newgrp docker
docker ps
```

### 8.4 镜像拉取失败

确认服务器能访问 Docker 镜像仓库。镜像已经在本地备好时，可以：

```bash
bash csgoj_deploy.sh web --DOCKER_PULL_NEW=0
```

Judge 同样：

```bash
bash csgoj_deploy.sh judge \
    --CSGOJ_SERVER_BASE_URL=http://<Web服务器IP或域名>:20080 \
    --CSGOJ_SERVER_USERNAME=<评测机账号> \
    --CSGOJ_SERVER_PASSWORD=<评测机密码> \
    --DOCKER_PULL_NEW=0
```

### 8.5 Judge 提示内核或 memory.peak 不满足

评测机需要 cgroup v2 的内存峰值监控。脚本提示内核过旧、缺少 `memory.peak`、或要求 5.19 以上内核时，先升级内核再重启：

```bash
sudo apt-get update
sudo apt-get install -y linux-generic-hwe-22.04
sudo reboot
```

## 9. 正式上线检查

- [ ] Web 服务器系统版本、磁盘、网络正常
- [ ] 数据目录已固定，例如 `/csgoj_data`
- [ ] `PORT_OJ`、`PORT_MYADMIN`、`PORT_DB` 未被占用
- [ ] 标准 XCPC 比赛系统已设 `OJ_MODE=cpcsys`
- [ ] 已改掉默认密码
- [ ] 首次访问 Web 已设好管理员账号
- [ ] Web 后台已有评测机账号
- [ ] Judge 的 `CSGOJ_SERVER_BASE_URL` 不是 `localhost` / `127.0.0.1`
- [ ] `docker ps` 里 Web 和 Judge 容器都在跑
- [ ] 提交一道测试题，评测机能取题、编译、运行并回传结果
- [ ] 已保存部署命令和 `./data/csgoj_config.cfg`
- [ ] `/csgoj_data` 有备份安排

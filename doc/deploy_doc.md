# 部署

用 `csgoj-deploy` 装比赛站。先装 Web，在网页里创建评测机账号，再在评测电脑上装评测容器。Web 和评测容器可以在同一台电脑，也可以分开。

> [!NOTE]
> **本文的两个说法**
>
> - “评测电脑”：用来评测的那台实体电脑。可以有多台，每台各自执行一次第 5 节的部署命令。
> - “评测容器”：评测电脑上运行的一个评测程序，一次只评一份提交。一台评测电脑可以开多个评测容器，个数由 `--pods` 决定。

命令在 Linux 终端执行。下面的 `mycpc`、端口和口令换成你自己的。

## 1. 准备机器

| 项目 | 要求 |
| --- | --- |
| 系统 | Ubuntu 22.04 / 24.04 / 26.04（x86_64） |
| 内核 | 评测电脑需要 5.19 以上。Ubuntu 24.04 起已满足 |
| CPU / 内存 | 每个评测容器 4 核 4GB（关闭超线程的物理机 2 核即可）。单机试用从 4 核 8GB 起。正式比赛按要开的评测容器总数配评测电脑 |
| 网络 | 机器要能上网。评测电脑要能打开 Web 的地址和端口 |

Ubuntu 22.04 如果内核低于 5.19，先升级再装评测容器：

```bash
sudo apt-get update
sudo apt-get install -y linux-generic-hwe-22.04
sudo reboot
```

## 2. Docker

不用手动装。部署工具第一次运行 `up` 或 `judge` 时，发现没有 Docker 会自动安装（Ubuntu，阿里云 docker-ce 源，含 compose 插件），并把当前用户加入 docker 组；已经装了就只确认服务在运行。只装原版 Docker，不配置镜像加速。

- 需要 sudo 权限，安装过程中可能要输入一次密码。
- 刚加入 docker 组要重新登录才生效，在此之前工具会自动用 sudo 执行 docker。
- 自动安装只支持 Ubuntu（含基于 Ubuntu 的发行版）。其它系统请先自行装好 Docker。
- Windows 上的 Linux 子系统：已开启 Docker Desktop 与 Linux 子系统的集成就直接用它（先在 Windows 上启动 Docker Desktop）；没有就在子系统里按 Ubuntu 安装。

## 3. 下载部署工具

到本仓库 [Releases](https://github.com/SZTU-ACM/CCPCOJ-2/releases) 下载 Linux x86_64 的 `csgoj-deploy`：

```bash
mkdir -p ~/csgoj && cd ~/csgoj
# <版本号> 用 Releases 页面上的版本，例如 2.0.268
wget -O csgoj-deploy https://github.com/SZTU-ACM/CCPCOJ-2/releases/download/<版本号>/csgoj-deploy_<版本号>_linux_amd64
chmod +x csgoj-deploy
./csgoj-deploy version
```

下不到时，在别的电脑下载，再用 `scp` 传到服务器。

## 4. 部署 Web

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
    --csgoj-version <版本号>
```

`<版本号>` 与第 3 节下载的部署工具相同。评测容器也填这一个版本。

| 参数 | 填写 |
| --- | --- |
| `--path-data` | 数据目录，写绝对路径。备份这个目录 |
| `--nginx-ranges` | 对外开放的端口范围。站点端口和 phpMyAdmin 端口要落在里面 |
| `--site` | `名称:端口:cpcsys:cpc`。名称只用字母和数字。后两个词照抄 |
| `--port-myadmin` | phpMyAdmin 端口 |
| `--port-db` | 填 `0` |
| `--sql-root` / `--sql-user-pass` / `--myadmin-pass` | 三个口令都自己设，只用字母和数字 |
| `--csgoj-version` | 第 3 节的版本号 |

第一次执行要下载，时间看网络。命令会等到站点页面能打开才结束。完成后打开：

```text
http://<服务器IP或域名>:20080
```

打不开时，到云服务器安全组放行这个端口。页面没有样式或图标时，等一分钟再刷新。

> [!TIP]
> **友情提示：数据放在固态硬盘上（仅供参考）**
>
> 数据目录（`--path-data`，MySQL 数据也在里面）和 Docker 的数据目录（默认 `/var/lib/docker`）都请放在固态硬盘上。放在机械硬盘上时，比赛中同时交题、刷新榜单的人一多，数据库读写跟不上，页面会明显卡顿。
>
> 查看硬盘类型和目录所在的盘：
>
> ```bash
> lsblk -d -o NAME,ROTA,SIZE,MODEL    # ROTA 为 1 是机械硬盘，0 是固态硬盘
> df -h /csgoj_data /var/lib/docker   # 看这两个目录在哪块盘上
> ```
>
> 虚拟机里显示的 ROTA 不一定准，以实体机的硬盘为准。

### 4.1 网页里接着做

1. 设置系统管理员账号和口令。用户名 5–20 位字母、数字或下划线。点「初始化系统」，在提示框点「确定」。
2. 页面进入「评测机管理」。之后也可以从管理后台 → 评测机进入。在「评测机列表」上方填好评测机口令和账号前缀，点旁边的添加按钮。

![评测机管理](deploy_doc_image/judger.png)

### 4.2 可选参数

第 4 节的命令已经够用。下面这些按需要加。

| 参数 | 用途 |
| --- | --- |
| `--secret-key` | 自定义加密密钥，不填用默认密钥。见 [4.3 加密密钥](#43-加密密钥) |
| `--no-mysql` | 不在本机起 MySQL，连已有的数据库，例如云数据库。要同时给 `--sql-host` |
| `--sql-host` / `--sql-port` | 外部数据库的地址和端口，端口默认 `3306`。只能和 `--no-mysql` 一起用 |
| `--sql-user` | 业务库用户名，默认 `csgcpc` |
| `--pull` / `--no-pull` | 默认本机没有镜像才下载。`--pull`：每次部署都重新下载；`--no-pull`：一律不下载，本机缺镜像直接报错 |
| `--pull-timeout` / `--pull-retries` | 每次下载最多等多少秒（默认 900，`0` 表示不限），一共试几次（默认 3） |

> [!IMPORTANT]
> **连外部数据库的要求**
>
> - 业务库用户（默认 `csgcpc`）要能建库，并能读写所有 `csgcpc_` 开头的库。站点第一次启动时会自己建库。
> - 数据库要允许 Web 所在的电脑连接。
> - 这时 `--sql-user-pass` 必须填，`--sql-root` 和 `--port-db` 用不到。phpMyAdmin 照常启动，连的是这个外部数据库。

> [!TIP]
> **友情提示（仅供参考）**：连外部数据库时，可以把第 4 节命令里的 `--sql-root` 和 `--port-db 0` 两行换成：
>
> ```bash
>     --no-mysql --sql-host 10.0.0.5 --sql-port 3306 \
>     --sql-user csgcpc \
> ```
>
> 机房断网时，可以先在能上网的电脑上用 `docker save` 导出镜像，拷过去用 `docker load` 导入，再在部署命令末尾加 `--no-pull`。

### 4.3 加密密钥

Web 用一个加密密钥（`--secret-key`）加密数据库里存的**队伍口令**和**评测机口令**，也用于站点内部的一些签名。它和登录会话无关，换不换都不会让已登录的人掉线。

| 情况 | 怎么做 |
| --- | --- |
| 新的公开部署 | 建议第一次部署时就用 `--secret-key` 指定自己的密钥，并另外记下来 |
| 内网、临时或测试部署 | 可以不指定，沿用默认密钥，部署时会打印一条提醒 |
| 已经在用的站点 | 不要换。部署工具会拒绝和原来不同的密钥 |
| 换服务器 | 数据目录整体搬走；指定过密钥的，密钥文件在数据目录里，一起搬即可 |

> [!IMPORTANT]
> - 密钥一旦用上就不能换。换了之后，已存的队伍口令和评测机口令都解不开，队伍和评测机会登录失败。
> - 指定过的密钥保存在 `<数据目录>/config/oj_secret`，备份数据目录时要包含它。
> - 默认密钥是公开的，公开部署建议自定义。

> [!TIP]
> **友情提示（仅供参考）**：第一次部署时生成一个随机密钥，例如
>
> ```bash
> csgoj-deploy up --path-data /csgoj_data --secret-key "$(openssl rand -hex 24)" ...
> ```
>
> 密钥只能用 16–128 位字母、数字、`-` 或 `_`。部署后到 `<数据目录>/config/oj_secret` 查看并另外记下（文件只有 root 可读）。

## 5. 在评测电脑上部署评测容器

在「评测机管理」里，双击该评测机账号那一行的连接状态图标。也可以单击图标打开登录日志，再点「复制部署命令」。剪贴板里是类似这样的命令：

```bash
sudo ./csgoj-deploy judge \
    --server-url http://<Web服务器IP或域名>:20080 \
    --username <评测机账号> \
    --password '<评测机口令>' \
    --oj-name <评测机账号> \
    --pods 1 \
    --csgoj-version <版本号>
```

到评测电脑上，进入放 `csgoj-deploy` 的目录，例如 `~/csgoj`，粘贴执行。

- `--server-url` 用评测电脑能打开的地址。复制出来如果是 `localhost` 或 `127.0.0.1`，改成服务器的 IP 或域名。
- `--csgoj-version` 与 Web 相同。复制出来的命令里没有这一项时，自己补上。
- `--pods` 是在这台评测电脑上开几个评测容器，不是评测电脑的台数。每个评测容器默认要 4 核 4GB；确认关闭了超线程时自动改为 2 核（见第 5.1 节）。内存不够时（例如 2 核 4GB 的虚拟机）会自动把每个评测容器的内存降到能放下的大小（最低 1.5GB）并提示；仍放不下时命令会写出最多能开几个。正式比赛建议评测电脑 8GB 内存以上。
- `--pods full`：按这台电脑上还没被占用的 CPU 和内存自动开满。已经在运行的容器（例如同机的 OJ 或其它评测机）绑定的核、占用的内存会先扣掉，再给系统留出 2 核（6 核以下的电脑少留）和 2GB 或总内存 10%（取大的）内存（不到 8GB 的电脑留 1GB），然后按每个评测容器的核数（同 `--pod-cpus`）+ `--pod-memory`（默认 4GB）+ 共享内存（1GB，不到 8GB 的电脑 256MB）计算，CPU 和内存两边取较小值。命令会打印计算过程；算出 0 个时直接报错，不启动容器。
- `--pod-memory` 可改每个评测容器的内存上限（GB），不写时默认 4GB。
- `--pod-cpus` 可指定每个评测容器用几个逻辑核，指定后以它为准。不写时：确认已关闭超线程用 2，开着超线程或无法确认（包括虚拟机、Windows 上的 Linux 子系统等虚拟化环境）用 4。
- 缺 `--server-url` 等参数时，在终端里会逐项提问，“每个评测容器的逻辑核数”一项会先显示超线程检测结果；加 `--noninteractive` 则缺参数直接报错。
- `--pull` / `--no-pull` 控制下载镜像，同第 4.2 节。
- 有多台评测电脑时，在每台上各执行一次部署命令，`--pods` 按各自配置填。

> [!NOTE]
> **评测容器的内存上限**
>
> 每个评测容器默认内存上限 4GB，另有 1GB 共享内存 `/dev/shm`（评测时的输入输出文件放在这里）。选手程序能用多少内存由题目的内存限制决定，不由这个值决定。一般不用改。
>
> 调大后这台评测电脑能开的评测容器可能变少，部署命令会检查内存够不够，不够时直接报错。

> [!TIP]
> **友情提示（仅供参考）**：部署命令加上 `--pod-memory 6` 即把每个评测容器的内存上限设为 6GB；不加时为默认 4GB。已有评测容器要先 `--remove-all` 再部署才会生效。

回到「评测机管理」，该评测机账号状态变为在线即可。

### 5.1 正式比赛的评测电脑与超线程

评测按 CPU 用时判超时。同一台评测电脑开多个评测容器（`--pods` 大于 1）时，如果开着超线程，两个评测容器可能挤在同一个物理核上，同一份代码的用时会忽长忽短。只开 1 个评测容器时影响很小。

> [!IMPORTANT]
> **正式比赛的评测电脑要求**
>
> - 用物理机评测，并关闭超线程。关闭后要删除并重新部署这台电脑上的评测容器。
> - Intel 12 代及以后的处理器只用性能核，不用能效核。
> - 不要用虚拟机、云服务器或Windows 上的 Linux 子系统等虚拟化环境当正式比赛的评测电脑来比时间。

> [!TIP]
> **友情提示（仅供参考，以实际机器为准）**
>
> - 不进 BIOS 也能关超线程：编辑 `/etc/default/grub`，在 `GRUB_CMDLINE_LINUX_DEFAULT` 的引号里加上 `nosmt`，然后：
>
>   ```bash
>   sudo update-grub
>   sudo reboot
>   cat /sys/devices/system/cpu/smt/active   # 显示 0 即已关闭
>   ```
>
> - 重新部署评测容器：先 `--remove-all`，再执行第 5 节的部署命令。
> - 关闭能效核：多数主板在 BIOS 的 CPU 设置里可以把能效核数量设为 0。

> [!NOTE]
> **每个评测容器用几个核**
>
> 部署命令每次都会用醒目的彩色框写出：检测到的超线程状态和依据、本次每个评测容器用几个核、为什么，以及怎么改。
>
> - 确认已关闭超线程（物理机上 `/sys/devices/system/cpu/smt/active` 为 0）：每个评测容器 2 核。
> - 开着超线程，或无法确认（读不到 CPU 信息，或在虚拟机、Windows 上的 Linux 子系统等虚拟化环境里，这些环境报告的 CPU 信息不可信）：每个评测容器 4 核。这样同一台电脑少开一半评测容器，但用时更稳。
> - 加 `--pod-cpus 2` 或 `--pod-cpus 4` 可以自己指定，指定后以它为准。已有评测容器要先 `--remove-all` 再部署才会生效。

> [!TIP]
> **友情提示：常见品牌 BIOS 按键与选项位置（仅供参考）**
>
> 按键和菜单因型号和 BIOS 版本而不同。Intel 主板多叫“Hyper-Threading”或“Intel HT Technology”，AMD 主板多叫“SMT”或“SMT Mode”，设为“Disabled”后保存重启。戴尔的“Multi Core Support”是关闭核心，不要改它。

| 品牌            | 开机按键                     | 选项位置与名称                                                          |
| --------------- | ---------------------------- | ----------------------------------------------------------------------- |
| 戴尔 Dell       | F2                           | “Performance”里的“Intel Hyper-Threading Technology”                     |
| 联想 Lenovo     | F1 或 F2，部分机型先按 Enter | “Advanced”或“Config”>“CPU”里的“Hyper-Threading Technology”              |
| 惠普 HP         | F10，部分机型先按 Esc        | “Advanced”>“System Options”或“Processor”里的“Hyper-Threading”           |
| 华硕 ASUS       | Del 或 F2                    | “Advanced”>“CPU Configuration”里的“Hyper-Threading”或“SMT Mode”         |
| 微星 MSI        | Del                          | “OC”或“Advanced”>“CPU Configuration”里的“Hyper-Threading”或“SMT Mode”   |
| 技嘉 Gigabyte   | Del                          | “Tweaker”或“Settings”>“CPU”里的“Hyper-Threading Technology”或“SMT Mode” |
| 华擎 ASRock     | F2 或 Del                    | “Advanced”>“CPU Configuration”里的“Hyper-Threading”或“SMT Mode”         |
| 超微 Supermicro | Del                          | “Advanced”>“CPU Configuration”里的“Hyper-Threading”或“SMT Control”      |

### 5.2 评测电脑的其他注意事项

**1. 关闭睡眠和休眠**

评测电脑睡眠后，上面的评测容器都会掉线，比赛中的提交会一直等待评测。

> [!IMPORTANT]
> 评测电脑在比赛期间不能睡眠或休眠，系统、桌面和 BIOS 里的睡眠都要关闭。

> [!TIP]
> **友情提示（仅供参考，以实际机器为准）**
>
> - 系统里禁止睡眠和休眠：
>
>   ```bash
>   sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
>   ```
>
> - 桌面版到“设置”>“电源”，关掉自动睡眠。
> - BIOS 里如有“ErP”“Deep Sleep”之类的节能睡眠选项，一并关闭。

**2. 电源用“性能”模式**

“平衡”或“节能”模式下 CPU 频率忽高忽低，同一份代码的用时会不稳定。

> [!IMPORTANT]
> 评测电脑的系统、BIOS 和 Windows 电源方案都要用“性能”或“高性能”，不要用“平衡”或“节能”。

> [!TIP]
> **友情提示（仅供参考，以实际机器为准）**
>
> - 桌面版执行 `powerprofilesctl set performance`，或在“设置”>“电源”里选“性能”。
> - 服务器版直接设置并检查：
>
>   ```bash
>   echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
>   cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor   # 每行都应是 performance
>   ```
>
> - 也可以先 `sudo apt install linux-tools-common linux-tools-$(uname -r)`，再执行 `sudo cpupower frequency-set -g performance`。
> - 以上设置重启后会恢复，每次开机后请重新执行。
> - BIOS 的电源方案选“性能”或“最高性能”；Windows 的电源计划选“高性能”。
> - 想让各评测电脑、各评测容器用时更一致，可以关闭睿频（整体会慢一些，重启后恢复）：
>
>   ```bash
>   echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo   # Intel
>   echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost            # AMD
>   ```

**3. 桌面版 Ubuntu 关闭图形界面**

图形界面会占用 CPU 和内存，还可能触发自动锁屏、睡眠和更新弹窗。

> [!IMPORTANT]
> 桌面版 Ubuntu 当评测电脑时，强烈建议关闭图形界面，开机直接进入命令行。

> [!TIP]
> **友情提示（仅供参考，以实际机器为准）**
>
> - 关闭图形界面：
>
>   ```bash
>   sudo systemctl set-default multi-user.target
>   sudo reboot
>   ```
>
> - 以后要恢复图形界面：
>
>   ```bash
>   sudo systemctl set-default graphical.target
>   sudo reboot
>   ```

## 6. 检查是否装好

```bash
sudo docker ps
```

应能看到 `db`、`csgoj-redis`、`myadmin`、`nginx-server`、`php-mycpc`，以及 `judge-<名称>`。一台电脑开多个评测容器时是 `judge-<名称>-1`、`judge-<名称>-2`。站点名称不是 `mycpc` 时，把 `php-mycpc` 里的 `mycpc` 换成你的站点名称。

```bash
sudo docker logs php-mycpc
sudo docker logs nginx-server
sudo docker logs -f judge-<名称>
```

评测容器的日志文件在 `/csgoj_data/var/log/judger/`。

再按 [办赛](user_doc.md) 走一遍：

1. 管理后台 → 题目 → 添加题目。保存后，在该题的「评测数据」里上传 `1.in` 和 `1.out`。
2. 管理后台 → 比赛 → 添加比赛，填好时间并加入这道题。在比赛列表里把状态改成「公开」。
3. 生成队伍账号，用队伍账号登录并提交。页面返回评测结果，榜单能打开。

## 7. 以后会用到的命令

```bash
./csgoj-deploy help
sudo ./csgoj-deploy judge --oj-name <名称> --restart-all
sudo ./csgoj-deploy judge --oj-name <名称> --remove-all
```

- 重装评测容器：先执行 `--remove-all`，再执行第 5 节复制的命令。
- 升级 Web：把 `--csgoj-version` 换成新版本，再执行第 4 节。数据还在。
- 升级评测容器：先 `--remove-all`，再执行第 5 节，版本号换成新的。
- 这台电脑多开评测容器：把 `--pods` 改大，再执行第 5 节。增加评测电脑：在新电脑上执行第 5 节。
- 再开一个站：第 4 节命令里再写一个 `--site 名称2:20081:cpcsys:cpc`，端口仍在 `--nginx-ranges` 里，然后重新执行。

## 8. 遇到这些问题

**评测机账号不在线。** 执行 `sudo docker logs judge-<名称>`。核对 `--server-url` 不是本机地址、端口已放行、账号口令与网页里一致。

**端口被占用。** 执行 `ss -tuln | grep -E '20080|20050'`，换端口后重新执行第 4 节。

**提示内核版本不够。** 按第 1 节升级内核并重启。

**下载失败。** 确认机器能上网，再执行一次。

**docker 权限错误。** 命令前加 `sudo`，或按第 2 节把用户加入 docker 组后重新登录。

## 9. 上线前核对

- [ ] 数据目录已固定，例如 `/csgoj_data`，磁盘够用，并已安排备份
- [ ] 三个口令都已自己设置，`--port-db` 是 `0`
- [ ] 指定过加密密钥的，密钥文件 `<数据目录>/config/oj_secret` 已随数据目录一起备份
- [ ] 已设置管理员和评测机账号
- [ ] 每台评测电脑的 `--server-url` 不是 localhost，状态为在线
- [ ] `sudo docker ps` 里 Web 和评测容器都在运行
- [ ] 提交一道题能返回结果，榜单能打开
- [ ] 本次部署命令已保存，其中含版本号

## 10. 从旧版部署脚本换过来

以前用 `csgoj_deploy.sh` 等 sh 脚本部署过的，注意下面这些默认值和旧脚本不一样。照着旧命令填参数，容易对不上。

| 项目 | 旧 sh 脚本 | csgoj-deploy |
| --- | --- | --- |
| 参数写法 | `--PATH_DATA=...`，大写加等号，可读配置文件 | `--path-data ...`，小写，不读配置文件 |
| 数据目录 | 默认 `$(pwd)/data/csgoj_data`，即执行命令时所在目录下 | Web 用 `--path-data` 写明（第 4 节用 `/csgoj_data`）；评测容器默认 `/csgoj_data` |
| 评测容器的 OJ 名 | 默认 `ccpc`，容器名 `judge-ccpc` | 默认 `csgoj`，容器名 `judge-csgoj`。网页复制的命令会带 `--oj-name` |
| MySQL 宿主机端口 | 默认 `20006` | 默认 `20306`。第 4 节用 `0`，不映射 |
| Redis 会话 | 默认不开 | 默认开，会起 `csgoj-redis` 容器。不要时加 `--no-redis` |
| 站点 | 不给参数时建一个 `ccpc` 站点（20080，cpcsys/cpc） | 必须用 `--site` 写明，不给直接报错 |
| 口令 | 不给时都是 `987654321` | `--sql-root` 必填；`--sql-user-pass` 不填时与 root 口令相同；`--myadmin-pass` 不填时与业务口令相同 |
| 镜像版本 | 脚本的发行版本号 | 部署工具的版本号（`csgoj-deploy version` 可查） |
| 下载镜像 | 默认每次都下载最新的 | 默认本机没有才下载，要每次下载加 `--pull` |
| 加密密钥 | 所有站点用镜像里的默认密钥 | 默认用镜像里的默认密钥（会打印提醒）；可以用 `--secret-key` 指定，指定后保存并沿用 |
| 时区 | 取这台电脑的时区 | 默认 `Asia/Shanghai` |

> [!IMPORTANT]
> **接着用旧的数据目录时**
>
> - `--path-data` 指到原来的数据目录，写绝对路径。例如以前在 `/home/ubuntu/csgoj` 下执行旧脚本，就是 `/home/ubuntu/csgoj/data/csgoj_data`。
> - 评测容器的 `--oj-name` 和旧的保持一致（旧默认 `ccpc`），或者先删掉旧的 `judge-ccpc` 容器再部署。不要让两套评测容器同时在跑。
> - 旧部署映射过 MySQL 端口 `20006`，换工具后改成 `--port-db` 的值。有别的程序连这个端口时，要一起改。

> [!TIP]
> **友情提示（仅供参考）**：查看这台电脑上已有的评测容器和它们的名字：
>
> ```bash
> sudo docker ps -a --filter name=judge-
> ```

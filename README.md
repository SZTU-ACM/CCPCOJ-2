# CCPCOJ 2.x 文档与部署

本仓库提供 [CCPCOJ](https://github.com/SZTU-ACM/CCPCOJ) **2.x** 的用户文档、部署说明与部署工具。**不含源码**；业务以 Docker 镜像发布。

## 目录

| 路径 | 说明 |
| --- | --- |
| [doc/user_doc.md](doc/user_doc.md) | 用户文档：组织 XCPC 标准赛（比赛系统） |
| [doc/deploy_doc.md](doc/deploy_doc.md) | 部署文档：Web / 评测机 |
| [Releases](../../releases) | 部署工具 `csgoj-deploy`（Linux amd64 / arm64、Windows） |

## 快速开始

1. 从 [Releases](../../releases) 下载 `csgoj-deploy`。
2. 按 [doc/deploy_doc.md](doc/deploy_doc.md) 部署 Web，网页初始化后在「评测机管理」复制命令部署评测机。
3. 办赛操作见 [doc/user_doc.md](doc/user_doc.md)。

## 镜像

正式镜像托管在：

- 腾讯云容器镜像服务：`ccr.ccs.tencentyun.com/csgrandeur/ccpcoj-web2`、`…/ccpcoj-judge2`
- Docker Hub：`csgrandeur/ccpcoj-web2`、`csgrandeur/ccpcoj-judge2`

部署工具会**优先从腾讯云拉取**，不可用时再回退到 Docker Hub。

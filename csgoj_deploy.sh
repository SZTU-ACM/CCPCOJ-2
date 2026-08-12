#!/bin/bash
# CSGOJ 统一部署脚本
# 版本时间: 2026-08-12 16:45:34
PASSWORD_DEFAULT=987654321
CONFIG_LOG='./data/config_log'
DEFAULT_CONFIG='./data/csgoj_config.cfg'

CONFIG_FILE=0
CSGOJ_VERSION=latest
PATH_DATA="${PATH_DATA:-$(pwd)/data/csgoj_data}"
NONINTERACTIVE=false
IGNORE_CONFIG=false

PASS_SQL_ROOT=$PASSWORD_DEFAULT
PASS_SQL_USER=$PASSWORD_DEFAULT
PASS_MYADMIN_PAGE=$PASSWORD_DEFAULT

PORT_OJ=20080
PORT_MYADMIN=20050
PORT_DB=20006
PORT_OJ_DB=3306

SQL_USER='csgcpc'
SQL_HOST='db'
WITH_MYSQL=1

OJ_NAME='ccpc'
OJ_CDN='local'
OJ_MODE='cpcsys'
OJ_STATUS='cpc'
OJ_OPEN_OI=0
OJ_UPDATE_STATIC=0
BELONG_TO=0

PROVIDED_BELONG_TO=false
PROVIDED_CPUSET_CPUS=false
PROVIDED_JUDGE_LAUNCH_CLI=false

APP_TIMEZONE=''
NGINX_PORT_RANGES=''
NGINX_EXTRA_MOUNTS=''
SECRET_KEY='super_secret_oj'
DOCKER_PULL_NEW=1
DOCKER_NET_NAME="csgoj_net"
LINK_LOCAL="--network $DOCKER_NET_NAME"

WEB_SSL=0
WEB_SSL_CERT=''
WEB_SSL_KEY=''
WEB_SSL_SERVER_NAME=''

CSGOJ_SERVER_BASE_URL=''
CSGOJ_SERVER_USERNAME=''
CSGOJ_SERVER_PASSWORD=''
JUDGE_POD_COUNT=1
RESTART_ALL=false
REBUILD_ALL=false
REMOVE_ALL=false

CPUSET_CPUS=""

show_help() {
    cat << EOF
CSGOJ 部署参数说明

使用方法:
  bash <script> [选项...]

基础配置:
  --CONFIG_FILE=<文件>           指定配置文件路径（优先级高于默认配置文件）
  --CSGOJ_VERSION=<版本>         Docker 镜像版本标签（默认: latest）
  --PATH_DATA=<路径>             数据目录绝对路径（默认: \$(pwd)/data/csgoj_data）
  --noninteractive, --no-interactive  非交互模式（参数缺失时使用默认值或报错）
  --ignore-config, --ignore-cfg  忽略默认配置文件（./data/csgoj_config.cfg），仅使用命令行参数和默认值

数据库配置:
  --PASS_SQL_ROOT=<密码>         MySQL root 用户密码（默认: 987654321）
  --PASS_SQL_USER=<密码>         MySQL 业务用户密码（默认: 987654321）
  --SQL_USER=<用户名>            MySQL 业务用户名（默认: csgcpc）
  --SQL_HOST=<主机>              MySQL 主机地址（默认: db）
  --WITH_MYSQL=<0|1>             是否部署 MySQL 容器（默认: 1）
  --PORT_DB=<端口>               MySQL 外部映射端口（默认: 20006）
  --PORT_OJ_DB=<端口>             OJ Web 连接 MySQL 的端口（默认: 3306）

OJ 配置:
  --OJ_NAME=<名称>               OJ 名称（默认: ccpc）
  --OJ_CDN=<local|jsdelivr>      静态资源 CDN 类型（默认: local）
  --OJ_MODE=<online|cpcsys>      OJ 运行模式（默认: cpcsys）
  --OJ_STATUS=<状态>             OJ 状态标识（默认: cpc）
  --OJ_OPEN_OI=<0|1>             [已废弃] OI 模式开关（默认: 0）
  --OJ_UPDATE_STATIC=<0|1>       新容器首次启动时是否从镜像强制刷新 baseoj 静态（默认: 0；docker restart 不重复）
  --BELONG_TO=<名称>             所属 OJ 名称，用于多实例共享（默认: 等于 OJ_NAME）
  --APP_TIMEZONE=<时区>          PHP/Python 与容器 TZ（IANA；未指定时默认取宿主机时区，无法检测则为 Asia/Shanghai）

端口配置:
  --PORT_OJ=<端口>               OJ Web 服务端口（默认: 20080）
  --PORT_MYADMIN=<端口>          PHPMyAdmin Web 端口（默认: 20050）
  --NGINX_PORT_RANGES=<映射>      额外的 Nginx 端口映射，支持多段，如 "-p 80-89:80-89 -p 443:443 -p 40030-40099:40030-40099"
  --NGINX_PORT_RANGE=<映射>      同上（兼容单数形式，建议使用 NGINX_PORT_RANGES）

Nginx 高级配置:
  --NGINX_EXTRA_MOUNTS=<挂载>     给 Nginx 追加自定义卷挂载（原样追加到 docker run），
                                例如 "-v /data/extra:/extra:ro -v /data/certs:/certs:ro"
  --NGINX_EXTRA_MOUNT=<挂载>      同上（兼容单数形式，建议使用 NGINX_EXTRA_MOUNTS）

Web SSL 配置（可选，默认关闭）:
  --WEB_SSL=<0|1>                是否为 OJ 站点生成 SSL Nginx 配置（默认: 0）
  --WEB_SSL_CERT=<路径>          SSL 证书 pem 路径（例如: /etc/nginx/attach/myssl/sztu.edu.cn.pem）
  --WEB_SSL_KEY=<路径>           SSL 私钥 key 路径（例如: /etc/nginx/attach/myssl/sztu.edu.cn.key）
  --WEB_SSL_SERVER_NAME=<域名>   SSL 站点域名（写入 nginx 的 server_name；默认: localhost）

其他配置:
  --PASS_MYADMIN_PAGE=<密码>     PHPMyAdmin 页面访问密码（默认: 987654321）
  --SECRET_KEY=<密钥>            系统加密密钥（默认: super_secret_oj）
  --DOCKER_PULL_NEW=<0|1>        是否拉取最新镜像（默认: 1，断网时设为 0）
  --DOCKER_NET_NAME=<名称>       Docker 网络名称（默认: csgoj_net）
  --LINK_LOCAL=<参数>            Docker 网络连接参数（默认: --network csgoj_net）

评测机绑核（可选）:
  --CPUSET_CPUS=<列表>           强制所有评测机 pod 使用同一段 cpuset（须本次命令行显式传入；空=多 pod 自动分配）

注意:
  • 管理员账号密码：首次访问 Web 页面时通过引导界面设置
  • 评测机账号密码：首次访问 Web 页面时通过引导界面设置
  • 参数优先级：命令行参数 > 配置文件 > 默认值
  • 使用 --CONFIG_FILE 可以批量设置参数，避免命令行过长
  • 默认交互模式：必要参数缺失时进入交互式补全
  • 非交互模式：使用 --noninteractive 时，参数缺失直接报错或使用默认值

示例:
  # OJ Web Server 部署（使用默认配置）
  bash deploy_dev.sh

  # OJ Web Server 部署（使用配置文件）
  bash deploy_dev.sh --CONFIG_FILE=my_config.cfg

  # OJ Web Server 部署（自定义参数）
  bash deploy_dev.sh --OJ_NAME=test --PATH_DATA=/data/csgoj --PORT_OJ=8080

  # 评测机节点部署
  bash deploy_dev.sh --CSGOJ_SERVER_BASE_URL=http://192.168.1.100:20080 --CSGOJ_SERVER_PASSWORD=123456

  提示: deploy_dev.sh 会根据参数自动判断部署内容（OJ Web Server 或 Judge Node）

EOF
}

parse_args() {
    for arg in "$@"; do
        if [ "$arg" = "--help" ] || [ "$arg" = "-h" ] || [ "$arg" = "-H" ]; then
            show_help
            exit 0
        fi
    done
    
    local pre_config_file=""
    local pre_ignore_config=false
    for arg in "$@"; do
        if [[ "$arg" == --CONFIG_FILE=* ]]; then
            pre_config_file="${arg#*=}"
        elif [[ "$arg" == --CONFIG_FILE ]]; then
            :
        elif [ "$arg" = "--ignore-config" ] || [ "$arg" = "--ignore-cfg" ]; then
            pre_ignore_config=true
        fi
    done
    
    if [ -n "$pre_config_file" ]; then
        CONFIG_FILE="$pre_config_file"
    fi
    if [ "$pre_ignore_config" = true ]; then
        IGNORE_CONFIG=true
    fi
    
    load_config_files
    
    local shortopts="h"
    local longopts="
        help,
        CONFIG_FILE:,
        CSGOJ_VERSION:,
        PATH_DATA:,
        PASS_SQL_ROOT:,
        PASS_SQL_USER:,
        PASS_MYADMIN_PAGE:,
        SQL_USER:,
        SQL_HOST:,
        WITH_MYSQL:,
        OJ_NAME:,
        OJ_CDN:,
        OJ_MODE:,
        OJ_STATUS:,
        OJ_OPEN_OI:,
        OJ_UPDATE_STATIC:,
        APP_TIMEZONE:,
        PORT_OJ:,
        PORT_OJ_DB:,
        PORT_MYADMIN:,
        PORT_DB:,
        BELONG_TO:,
        NGINX_PORT_RANGES:,
        NGINX_PORT_RANGE:,
        NGINX_EXTRA_MOUNTS:,
        NGINX_EXTRA_MOUNT:,
        WEB_SSL:,
        WEB_SSL_CERT:,
        WEB_SSL_KEY:,
        WEB_SSL_SERVER_NAME:,
        SECRET_KEY:,
        DOCKER_PULL_NEW:,
        DOCKER_NET_NAME:,
        LINK_LOCAL:,
        CSGOJ_SERVER_BASE_URL:,
        CSGOJ_SERVER_USERNAME:,
        CSGOJ_SERVER_PASSWORD:,
        JUDGE_POD_COUNT:,
        CPUSET_CPUS:,
        restart-all,
        rebuild-all,
        remove-all,
        delete-all,
        noninteractive,
        no-interactive,
        ignore-config,
        ignore-cfg
    "
    
    local opts
    opts=$(getopt -o "$shortopts" --long "$longopts" -n "$0" -- "$@") || {
        echo "❌ 参数解析失败，使用 --help 查看帮助信息" >&2
        exit 1
    }
    
    eval set -- "$opts"
    
    while true; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --CONFIG_FILE)                  # 指定配置文件路径
                CONFIG_FILE="$2"
                shift 2
                ;;
            --CSGOJ_VERSION)                # Docker 镜像版本标签
                CSGOJ_VERSION="$2"
                shift 2
                ;;
            --PATH_DATA)                    # 数据目录绝对路径
                PATH_DATA="$2"
                PROVIDED_JUDGE_LAUNCH_CLI=true
                shift 2
                ;;
            --PASS_SQL_ROOT)                # MySQL root 用户密码
                PASS_SQL_ROOT="$2"
                shift 2
                ;;
            --PASS_SQL_USER)                # MySQL 业务用户密码
                PASS_SQL_USER="$2"
                shift 2
                ;;
            --PASS_MYADMIN_PAGE)            # PHPMyAdmin 页面访问密码
                PASS_MYADMIN_PAGE="$2"
                shift 2
                ;;
            --SQL_USER)                     # MySQL 业务用户名
                SQL_USER="$2"
                shift 2
                ;;
            --SQL_HOST)                     # MySQL 主机地址
                SQL_HOST="$2"
                shift 2
                ;;
            --WITH_MYSQL)                   # 是否部署 MySQL 容器
                WITH_MYSQL="$2"
                shift 2
                ;;
            --OJ_NAME)                      # OJ 名称
                OJ_NAME="$2"
                PROVIDED_JUDGE_LAUNCH_CLI=true
                shift 2
                ;;
            --OJ_CDN)                       # 静态资源 CDN 类型
                OJ_CDN="$2"
                shift 2
                ;;
            --OJ_MODE)                      # OJ 运行模式
                OJ_MODE="$2"
                shift 2
                ;;
            --OJ_STATUS)                    # OJ 状态标识
                OJ_STATUS="$2"
                shift 2
                ;;
            --OJ_OPEN_OI)                   # [已废弃] OI 模式开关
                OJ_OPEN_OI="$2"
                shift 2
                ;;
            --OJ_UPDATE_STATIC)             # 新容器首次启动时是否强制刷新 baseoj 静态
                OJ_UPDATE_STATIC="$2"
                shift 2
                ;;
            --APP_TIMEZONE)                 # 应用时区（IANA）
                APP_TIMEZONE="$2"
                shift 2
                ;;
            --PORT_OJ)                      # OJ Web 服务端口
                PORT_OJ="$2"
                shift 2
                ;;
            --PORT_OJ_DB)                   # OJ Web 连接 MySQL 的端口
                PORT_OJ_DB="$2"
                shift 2
                ;;
            --PORT_MYADMIN)                 # PHPMyAdmin Web 端口
                PORT_MYADMIN="$2"
                shift 2
                ;;
            --PORT_DB)                      # MySQL 外部映射端口
                PORT_DB="$2"
                shift 2
                ;;
            --BELONG_TO)                    # 所属 OJ 名称，用于多实例共享
                BELONG_TO="$2"
                PROVIDED_BELONG_TO=true
                shift 2
                ;;
            --NGINX_PORT_RANGES)             # 额外的 Nginx 端口映射
                NGINX_PORT_RANGES="$2"
                shift 2
                ;;
            --NGINX_PORT_RANGE)              # 额外的 Nginx 端口映射（兼容单数形式）
                NGINX_PORT_RANGES="$2"
                shift 2
                ;;
            --NGINX_EXTRA_MOUNTS)            # 追加的 Nginx 自定义挂载（原样追加到 docker run）
                NGINX_EXTRA_MOUNTS="$2"
                shift 2
                ;;
            --NGINX_EXTRA_MOUNT)             # 追加的 Nginx 自定义挂载（兼容单数形式）
                NGINX_EXTRA_MOUNTS="$2"
                shift 2
                ;;
            --WEB_SSL)                      # Web SSL 开关（0/1）
                WEB_SSL="$2"
                shift 2
                ;;
            --WEB_SSL_CERT)                 # Web SSL 证书路径（pem）
                WEB_SSL_CERT="$2"
                shift 2
                ;;
            --WEB_SSL_KEY)                  # Web SSL 私钥路径（key）
                WEB_SSL_KEY="$2"
                shift 2
                ;;
            --WEB_SSL_SERVER_NAME)          # Web SSL server_name
                WEB_SSL_SERVER_NAME="$2"
                shift 2
                ;;
            --SECRET_KEY)                   # 系统加密密钥
                SECRET_KEY="$2"
                shift 2
                ;;
            --DOCKER_PULL_NEW)              # 是否拉取最新镜像
                DOCKER_PULL_NEW="$2"
                shift 2
                ;;
            --DOCKER_NET_NAME)              # Docker 网络名称
                DOCKER_NET_NAME="$2"
                LINK_LOCAL="--network $DOCKER_NET_NAME"
                shift 2
                ;;
            --LINK_LOCAL)                   # Docker 网络连接参数
                LINK_LOCAL="$2"
                shift 2
                ;;
            --CSGOJ_SERVER_BASE_URL)        # Judge 模式：OJ Web 服务器地址
                if [ -n "$2" ] && [[ "$2" != --* ]]; then
                    CSGOJ_SERVER_BASE_URL="$2"
                    PROVIDED_JUDGE_LAUNCH_CLI=true
                    shift 2
                else
                    echo "❌ 错误: --CSGOJ_SERVER_BASE_URL 需要提供值" >&2
                    exit 1
                fi
                ;;
            --CSGOJ_SERVER_USERNAME)        # Judge 模式：评测机用户名
                if [ -n "$2" ] && [[ "$2" != --* ]]; then
                    CSGOJ_SERVER_USERNAME="$2"
                    PROVIDED_JUDGE_LAUNCH_CLI=true
                    shift 2
                else
                    echo "❌ 错误: --CSGOJ_SERVER_USERNAME 需要提供值" >&2
                    exit 1
                fi
                ;;
            --CSGOJ_SERVER_PASSWORD)        # Judge 模式：评测机密码
                if [ -n "$2" ] && [[ "$2" != --* ]]; then
                    CSGOJ_SERVER_PASSWORD="$2"
                    PROVIDED_JUDGE_LAUNCH_CLI=true
                    shift 2
                else
                    echo "❌ 错误: --CSGOJ_SERVER_PASSWORD 需要提供值" >&2
                    exit 1
                fi
                ;;
            --JUDGE_POD_COUNT)              # Judge 模式：启动的 pod 数量
                if [ -n "$2" ] && [[ "$2" != --* ]]; then
                    JUDGE_POD_COUNT="$2"
                    PROVIDED_JUDGE_LAUNCH_CLI=true
                    shift 2
                else
                    JUDGE_POD_COUNT=1  # 默认值
                    shift
                fi
                ;;
            --CPUSET_CPUS)                  # Judge 模式：强制 cpuset（允许重叠）
                PROVIDED_JUDGE_LAUNCH_CLI=true
                if [ -n "$2" ] && [[ "$2" != --* ]]; then
                    CPUSET_CPUS="$2"
                    PROVIDED_CPUSET_CPUS=true
                    shift 2
                else
                    CPUSET_CPUS=""
                    shift
                fi
                ;;
            --restart-all)                  # Judge 模式：重启所有 pod
                RESTART_ALL=true
                shift
                ;;
            --rebuild-all)                  # Judge 模式：重开所有 pod
                REBUILD_ALL=true
                shift
                ;;
            --remove-all|--delete-all)      # Judge 模式：删除所有 pod
                REMOVE_ALL=true
                shift
                ;;
            --noninteractive|--no-interactive)  # 非交互模式
                NONINTERACTIVE=true
                shift
                ;;
            --ignore-config|--ignore-cfg)  # 忽略配置文件
                IGNORE_CONFIG=true
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "❌ 未知参数: '$1'，使用 --help 查看帮助信息" >&2
                exit 1
                ;;
        esac
    done
    
    if [ "$PROVIDED_BELONG_TO" != "true" ]; then
        BELONG_TO="$OJ_NAME"
    elif [ "$BELONG_TO" = "0" ] || [ -z "$BELONG_TO" ]; then
        BELONG_TO="$OJ_NAME"
    fi

    if [ "$PROVIDED_CPUSET_CPUS" != "true" ]; then
        if [ "$PROVIDED_JUDGE_LAUNCH_CLI" = "true" ]; then
            CPUSET_CPUS=""
        fi
    fi
    
    if [ -n "$PATH_DATA" ] && [[ "$PATH_DATA" != /* ]]; then
        if command -v realpath >/dev/null 2>&1; then
            PATH_DATA=$(realpath -m "$PATH_DATA" 2>/dev/null || echo "$(pwd)/$PATH_DATA")
        else
            PATH_DATA="$(pwd)/$PATH_DATA"
        fi
        if [[ "$PATH_DATA" != /* ]]; then
            PATH_DATA="$(pwd)/$PATH_DATA"
        fi
    fi

    if [ -z "${APP_TIMEZONE:-}" ]; then
        if [ -n "${TZ:-}" ]; then
            APP_TIMEZONE="$TZ"
        elif command -v timedatectl >/dev/null 2>&1; then
            APP_TIMEZONE=$(timedatectl show -p Timezone --value 2>/dev/null || true)
        fi
        if [ -z "${APP_TIMEZONE:-}" ] && [ -f /etc/timezone ]; then
            APP_TIMEZONE=$(cat /etc/timezone 2>/dev/null | tr -d ' \t\r\n' || true)
        fi
        if [ -z "${APP_TIMEZONE:-}" ]; then
            APP_TIMEZONE='Asia/Shanghai'
        fi
    fi
}

load_config_files() {
    if [ "$IGNORE_CONFIG" = true ]; then
        return 0
    fi
    
    if [ -f "$DEFAULT_CONFIG" ]; then
        source "$DEFAULT_CONFIG"
    fi
    
    if [ -n "$CONFIG_FILE" ] && [ "$CONFIG_FILE" != "0" ] && [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}


init_config_log() {
    mkdir -p "$CONFIG_LOG"
}

init_docker_network() {
    if command -v docker &> /dev/null; then
        if [ -z "$(docker network ls | grep "$DOCKER_NET_NAME")" ]; then
            docker network create "$DOCKER_NET_NAME" >/dev/null 2>&1 || true
        fi
    fi
}

init_data_directory() {
    if [ ! -d "$PATH_DATA" ]; then
        mkdir -p "$PATH_DATA"
        if [ "$EUID" -eq 0 ]; then
            chown -R "$USER" "$PATH_DATA" 2>/dev/null || true
        fi
        chmod 755 "$PATH_DATA" 2>/dev/null || true
    fi
}

write_full_config_file() {
    local target_config_file="${1:-$DEFAULT_CONFIG}"
    local deploy_mode="${2:-web}"  # web 或 judge
    
    local config_dir=$(dirname "$target_config_file")
    if [ -n "$config_dir" ] && [ "$config_dir" != "." ]; then
        mkdir -p "$config_dir"
    fi
    
    local belong_to_value="$BELONG_TO"
    if [ "$belong_to_value" = "0" ] || [ -z "$belong_to_value" ]; then
        belong_to_value="$OJ_NAME"
    fi
    
    local existing_web_config=""
    local existing_judge_config=""
    if [ -f "$target_config_file" ]; then
        if grep -q "# ==================== OJ Web Server 配置 ====================" "$target_config_file" 2>/dev/null; then
            existing_web_config=$(sed -n '/^# ==================== OJ Web Server 配置 ====================$/,$p' "$target_config_file" 2>/dev/null | sed '/^# ==================== Judge Node 配置 ====================$/,$d')
        fi
        if grep -q "# ==================== Judge Node 配置 ====================" "$target_config_file" 2>/dev/null; then
            existing_judge_config=$(sed -n '/^# ==================== Judge Node 配置 ====================$/,$p' "$target_config_file" 2>/dev/null)
        fi
    fi
    
    cat > "$target_config_file" <<EOF
# CSGOJ 部署配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 部署内容: OJ Web Server + Judge Node（支持同时配置）
# 
# 说明：
#   - 此文件包含所有配置参数（包括默认值）
#   - 下次运行时不提供参数，将自动使用此配置文件
#   - 参数优先级：命令行参数 > 此配置文件 > 默认值
#   - 配置文件支持同时包含 Web 和 Judge 两套配置

# ==================== 基础配置 ====================
PATH_DATA="$PATH_DATA"
OJ_NAME="$OJ_NAME"
CSGOJ_VERSION="$CSGOJ_VERSION"
DOCKER_NET_NAME="$DOCKER_NET_NAME"
DOCKER_PULL_NEW=$DOCKER_PULL_NEW
LINK_LOCAL="--network $DOCKER_NET_NAME"
EOF

    if [ "$deploy_mode" = "web" ]; then
        cat >> "$target_config_file" <<EOF

# ==================== OJ Web Server 配置 ====================
# MySQL 配置
WITH_MYSQL=${WITH_MYSQL:-1}
SQL_HOST="${SQL_HOST}"
SQL_USER="${SQL_USER:-csgcpc}"
PASS_SQL_ROOT="${PASS_SQL_ROOT}"
PASS_SQL_USER="${PASS_SQL_USER:-987654321}"
PORT_DB=${PORT_DB}
PORT_OJ_DB=${PORT_OJ_DB:-3306}

# OJ Web 配置
PORT_OJ=${PORT_OJ:-20080}
PORT_MYADMIN=${PORT_MYADMIN:-20050}
OJ_CDN="${OJ_CDN:-local}"
OJ_MODE="${OJ_MODE:-cpcsys}"
OJ_STATUS="${OJ_STATUS:-cpc}"
OJ_OPEN_OI=${OJ_OPEN_OI:-0}
OJ_UPDATE_STATIC=${OJ_UPDATE_STATIC:-0}
EOF
        if [ "$PROVIDED_BELONG_TO" = "true" ]; then
            echo "BELONG_TO=\"${belong_to_value}\"" >> "$target_config_file"
        fi
        
        cat >> "$target_config_file" <<EOF

# 其他配置
PASS_MYADMIN_PAGE="${PASS_MYADMIN_PAGE:-987654321}"
SECRET_KEY="${SECRET_KEY:-super_secret_oj}"
APP_TIMEZONE="${APP_TIMEZONE:-Asia/Shanghai}"
NGINX_PORT_RANGES="${NGINX_PORT_RANGES}"
WEB_SSL=${WEB_SSL:-0}
WEB_SSL_CERT="${WEB_SSL_CERT}"
WEB_SSL_KEY="${WEB_SSL_KEY}"
WEB_SSL_SERVER_NAME="${WEB_SSL_SERVER_NAME}"
EOF
    elif [ -n "$existing_web_config" ]; then
        echo "" >> "$target_config_file"
        echo "$existing_web_config" >> "$target_config_file"
    fi
    
    if [ "$deploy_mode" = "judge" ]; then
        cat >> "$target_config_file" <<EOF

# ==================== Judge Node 配置 ====================
CSGOJ_SERVER_BASE_URL="$CSGOJ_SERVER_BASE_URL"
CSGOJ_SERVER_USERNAME="$CSGOJ_SERVER_USERNAME"
CSGOJ_SERVER_PASSWORD="$CSGOJ_SERVER_PASSWORD"
JUDGE_POD_COUNT=${JUDGE_POD_COUNT:-1}
EOF
        if [ "$PROVIDED_CPUSET_CPUS" = "true" ]; then
            echo "CPUSET_CPUS=\"${CPUSET_CPUS}\"" >> "$target_config_file"
        else
            cat >> "$target_config_file" <<'EOF'
# CPUSET_CPUS 留空：多 pod 时按宿主机自动分配；仅 CLI 传入 --CPUSET_CPUS 时才会写入上一行变量
CPUSET_CPUS=""
EOF
        fi
    elif [ -n "$existing_judge_config" ]; then
        echo "" >> "$target_config_file"
        echo "$existing_judge_config" >> "$target_config_file"
    fi
    
    echo "$target_config_file"
}

write_config_if_changed() {
    init_config_log
    
    local latest_config_file=""
    if [ -d "${CONFIG_LOG}" ] && [ "$(ls -A ${CONFIG_LOG}/csgoj_config_*.cfg 2>/dev/null)" ]; then
        latest_config_file=$(ls -t ${CONFIG_LOG}/csgoj_config_*.cfg 2>/dev/null | head -n 1)
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    for arg in "$@"; do
        if [[ $arg == --* ]] && [[ ${arg%%=*} != "--CONFIG_FILE" ]]; then
            echo "${arg:2}" >> "$temp_file"
        fi
    done
    
    if [[ -s $temp_file ]] && { [ -z "$latest_config_file" ] || ! diff -q "$temp_file" "$latest_config_file" >/dev/null 2>&1; }; then
        local timestamp
        timestamp=$(date +%s)
        local new_config_file="${CONFIG_LOG}/csgoj_config_${timestamp}.cfg"
        mv "$temp_file" "$new_config_file"
        echo "📝 新建配置记录: $new_config_file"
    else
        rm -f "$temp_file"
    fi
}


install_docker() {
    local target_user="${SUDO_USER:-$USER}"
    local need_restart=0
    local docker_preinstalled=0

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  检查 Docker 安装"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if command -v docker &> /dev/null; then
        docker_preinstalled=1
        echo "✅ Docker 已安装"
        docker --version
    else
        echo "📦 开始安装 Docker CE..."
        
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
            sudo apt-get remove -y "$pkg" 2>/dev/null || true
        done
        
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | \
            sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt-get update
        sudo apt-get install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin
        need_restart=1
    fi
    
    sudo groupadd docker 2>/dev/null || true
    if id -nG "$target_user" | tr ' ' '\n' | grep -qx docker; then
        echo "ℹ️  用户 $target_user 已在 docker 组中"
    else
        sudo gpasswd -a "$target_user" docker
        echo "✅ 已将用户 $target_user 加入 docker 组"
    fi
    
    if [ "$docker_preinstalled" -eq 0 ]; then
        sudo mkdir -p /etc/docker
        local tmp_daemon_json
        tmp_daemon_json="$(mktemp)"
        cat > "$tmp_daemon_json" <<EOF
{
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://dockerproxy.net",
        "https://proxy.vvvv.ee",
        "https://dockerproxy.link"
    ]
}
EOF

        if ! sudo test -f /etc/docker/daemon.json || ! sudo cmp -s "$tmp_daemon_json" /etc/docker/daemon.json; then
            sudo cp "$tmp_daemon_json" /etc/docker/daemon.json
            need_restart=1
            echo "✅ 已更新 Docker 镜像加速配置"
        else
            echo "ℹ️  Docker 镜像加速配置无变化"
        fi
        rm -f "$tmp_daemon_json"
    else
        echo "ℹ️  检测到 Docker 已安装，跳过镜像加速配置更新"
    fi
    
    if [ "$need_restart" -eq 1 ]; then
        sudo service docker restart
        echo "✅ 已重启 Docker 服务"
    else
        echo "ℹ️  无需重启 Docker 服务"
    fi
    
    echo ""
    echo "✅ Docker 安装完成"
    echo ""

    if sudo -iu "$target_user" bash -lc "docker ps >/dev/null 2>&1"; then
        echo "✅ 自检通过: 用户 $target_user 已可使用 Docker"
    else
        echo "⚠️  自检失败: 请检查 /var/run/docker.sock 权限或 Docker 服务状态"
    fi

    if docker ps >/dev/null 2>&1; then
        echo "✅ 当前终端也可直接使用 docker"
    else
        echo "⚠️  当前终端尚未刷新组身份，请执行下面这一条命令后再试:"
        echo "   newgrp docker"
        echo "   然后执行: docker ps"
    fi
    echo ""
}

start_db() {
    if [ "$WITH_MYSQL" != "1" ]; then
        echo "⚠️  WITH_MYSQL=0，跳过 MySQL 容器启动"
        return 0
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  初始化 MySQL 数据库"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    mkdir -p "$PATH_DATA/var/mysql/mysql_config"
    mkdir -p "$PATH_DATA/var/mysql/mysql_init"

    cat > "$PATH_DATA/var/mysql/mysql_config/oj_my.cnf" <<EOF
[mysqld]
# 多 PHP-FPM 池共用；开赛高峰按「活跃 worker」计连接，仍保留余量
max_connections=8000
mysqlx_max_connections=800
innodb_buffer_pool_size=512M
default-time-zone='+8:00'
EOF
    chmod 644 "$PATH_DATA/var/mysql/mysql_config/oj_my.cnf"

    if [ -n "$(docker ps -aq -f name=^db$)" ]; then
        echo "✅ MySQL 容器已存在（已刷新 $PATH_DATA/var/mysql/mysql_config/oj_my.cnf，生效须 restart db）"
    else
        echo "GRANT ALL PRIVILEGES ON \`${SQL_USER}_%\`.* TO '${SQL_USER}'@'%';" > "$PATH_DATA/var/mysql/mysql_init/init.sql"
        
        docker run -dit $LINK_LOCAL \
            --name db \
            -p "$PORT_DB:3306" \
            -v "$PATH_DATA/var/mysql/mysql_data:/var/lib/mysql" \
            -v "$PATH_DATA/var/mysql/mysql_config:/etc/mysql/conf.d" \
            -v "$PATH_DATA/var/mysql/mysql_init:/docker-entrypoint-initdb.d" \
            -e MYSQL_ROOT_PASSWORD="$PASS_SQL_ROOT" \
            -e MYSQL_USER="$SQL_USER" \
            -e MYSQL_PASSWORD="$PASS_SQL_USER" \
            --restart=unless-stopped \
            mysql:8.0.32 \
            --default-authentication-plugin=mysql_native_password
        
        echo "✅ MySQL 容器启动成功"
    fi
    echo ""
}

start_myadmin() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  初始化 PHPMyAdmin"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -n "$(docker ps -aq -f name=^myadmin$)" ]; then
        echo "✅ PHPMyAdmin 容器已存在"
        mkdir -p "$PATH_DATA/nginx/attach"
        echo "admin:$(openssl passwd -apr1 "$PASS_MYADMIN_PAGE")" > "$PATH_DATA/nginx/attach/pass"
    else
        mkdir -p "$PATH_DATA/nginx/attach"
        mkdir -p "$PATH_DATA/nginx/nginx_conf.d"
        
        echo "admin:$(openssl passwd -apr1 "$PASS_MYADMIN_PAGE")" > "$PATH_DATA/nginx/attach/pass"
        
        cat > "$PATH_DATA/nginx/nginx_conf.d/myadmin.conf" <<EOF
server {
    listen $PORT_MYADMIN;
    charset utf-8;
    client_max_body_size 512m;
    keepalive_timeout 65s;
    client_body_timeout 60s;
    server_name localhost;

    proxy_read_timeout 300s;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_buffer_size 128k; 
    proxy_buffers 4 256k; 
    proxy_busy_buffers_size 256k;

    location / {
        proxy_redirect          off;
        proxy_set_header        Host      \$http_host;
        proxy_set_header        X-Real-IP \$remote_addr;
        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass              http://myadmin;
        auth_basic              "验证后访问";
        auth_basic_user_file    "/etc/nginx/attach/pass";
    }
    
    access_log /var/log/nginx/myadmin_access.log;
    error_log /var/log/nginx/myadmin_error.log;
}
EOF
        
        local docker_run_args=(
            "run"
            "-dit"
            "--name" "myadmin"
        )
        
        if [ -n "${LINK_LOCAL:-}" ]; then
            read -ra link_local_args <<< "$LINK_LOCAL"
            docker_run_args+=("${link_local_args[@]}")
        fi
        
        docker_run_args+=(
            "-e" "PMA_HOST=$SQL_HOST"
            "-e" "UPLOAD_LIMIT=512M"
            "--restart=unless-stopped"
            "phpmyadmin:5.2.3"
        )
        
        local docker_run_output=""
        local docker_run_log
        docker_run_log=$(mktemp)
        docker "${docker_run_args[@]}" 2>&1 | tee "$docker_run_log"
        local docker_run_exit_code=$?
        if [ -f "$docker_run_log" ]; then
            docker_run_output=$(sed -n '1,50p' "$docker_run_log")
            rm -f "$docker_run_log"
        fi
        
        sleep 1
        if ! docker ps --format "{{.Names}}" | grep -q "^myadmin$"; then
            echo "❌ PHPMyAdmin 容器启动失败"
            echo "   docker run 输出："
            echo "$docker_run_output"
            echo ""
            if docker ps -a --format "{{.Names}}" | grep -q "^myadmin$"; then
                echo "   容器已创建但未运行，查看日志："
                docker logs "myadmin" 2>&1 | tail -15
                echo ""
                echo "   尝试清理失败的容器..."
                docker rm -f "myadmin" >/dev/null 2>&1 || true
            fi
            echo "   提示："
            echo "   - 检查镜像是否存在: docker images | grep phpmyadmin"
            echo "   - 检查 MySQL 连接: SQL_HOST=$SQL_HOST"
            echo "   - 检查网络连接: docker network ls | grep $DOCKER_NET_NAME"
            return 1
        fi
        
        echo "✅ PHPMyAdmin 容器启动成功"
    fi
    echo ""
}

start_ojweb() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  初始化 OJ Web 服务"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ ! -d "$PATH_DATA/var/www/$OJ_NAME" ]; then
        mkdir -p "$PATH_DATA/var/www/$OJ_NAME"
    fi
    
    if [ -n "$(docker ps -aq -f name=^php-$OJ_NAME$)" ]; then
        echo "✅ OJ Web 容器已存在"
    else
        local web_image=""
        local target_image="csgrandeur/ccpcoj-web2:$CSGOJ_VERSION"
        
        local skip_pull=false
        if [ "${DOCKER_PULL_NEW:-1}" = "0" ] || [ "${NO_DOCKER_PULL:-0}" = "1" ]; then
            skip_pull=true
        fi
        
        find_local_web_image() {
            local image_repo="csgrandeur/ccpcoj-web2"
            local latest_image="$image_repo:latest"
            if docker image inspect "$latest_image" >/dev/null 2>&1 && \
               docker run --pull=never --network none --rm --entrypoint /bin/sh "$latest_image" -c "echo test" >/dev/null 2>&1; then
                echo "$latest_image"
                return 0
            fi
            local local_images=$(docker images --format "{{.Repository}}:{{.Tag}}" "$image_repo" 2>/dev/null | grep -v "^$" || true)
            if [ -n "$local_images" ]; then
                for img in $local_images; do
                    if [ "$img" = "$latest_image" ]; then
                        continue
                    fi
                    if docker image inspect "$img" >/dev/null 2>&1 && \
                       docker run --pull=never --network none --rm --entrypoint /bin/sh "$img" -c "echo test" >/dev/null 2>&1; then
                        echo "$img"
                        return 0
                    fi
                done
            fi
            return 1
        }
        
        echo "📦 尝试使用镜像: $target_image"
        if docker image inspect "$target_image" >/dev/null 2>&1 && \
           docker run --pull=never --network none --rm --entrypoint /bin/sh "$target_image" -c "echo test" >/dev/null 2>&1; then
            web_image="$target_image"
            echo "✅ 使用镜像: $target_image (本地存在)"
        else
            if [ "$skip_pull" = true ]; then
                echo "⚠️  跳过镜像拉取（DOCKER_PULL_NEW=0 或 NO_DOCKER_PULL=1），尝试使用本地镜像"
                local found_image
                found_image=$(find_local_web_image)
                if [ $? -eq 0 ] && [ -n "$found_image" ]; then
                    web_image="$found_image"
                    if [ "$found_image" = "csgrandeur/ccpcoj-web2:latest" ]; then
                        echo "✅ 使用本地 latest 镜像: $web_image"
                    else
                        echo "⚠️  使用本地镜像: $web_image (fallback from $target_image)"
                    fi
                else
                    echo "❌ 无法找到有效的 OJ Web 镜像"
                    echo "   请检查网络连接或手动拉取: docker pull csgrandeur/ccpcoj-web2:$CSGOJ_VERSION"
                    return 1
                fi
            else
                echo "📥 正在拉取镜像: $target_image"
                echo "   请稍候，这可能需要一些时间..."
                echo ""
                if docker pull "$target_image"; then
                    web_image="$target_image"
                    echo ""
                    echo "✅ 镜像拉取成功: $target_image"
                else
                    echo ""
                    echo "⚠️  镜像 $target_image 拉取失败，尝试使用本地镜像"
                    local found_image
                    found_image=$(find_local_web_image)
                    if [ $? -eq 0 ] && [ -n "$found_image" ]; then
                        web_image="$found_image"
                        if [ "$found_image" = "csgrandeur/ccpcoj-web2:latest" ]; then
                            echo "✅ 使用本地 latest 镜像: $web_image"
                        else
                            echo "⚠️  使用本地镜像: $web_image (fallback from $target_image)"
                        fi
                    else
                        echo "❌ 无法找到有效的 OJ Web 镜像"
                        echo "   请检查网络连接或手动拉取: docker pull csgrandeur/ccpcoj-web2:$CSGOJ_VERSION"
                        return 1
                    fi
                fi
            fi
        fi
        
        WEB_MOUNT_ARGS=()
        if [ "$CSGOJ_DEV" = "1" ]; then
            local project_dir=""
            
            if [ -n "$SCRIPT_DIR" ]; then
                local temp_dir=$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd || echo "")
                if [ -n "$temp_dir" ] && [ -d "$temp_dir/ojweb" ]; then
                    project_dir="$temp_dir"
                fi
            fi
            
            if [ -z "$project_dir" ] || [ ! -d "$project_dir/ojweb" ]; then
                local script_dir=""
                if [ -n "${BASH_SOURCE[0]}" ]; then
                    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")
                fi
                if [ -z "$script_dir" ] && [ -n "$0" ]; then
                    script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")
                fi
                
                if [ -n "$script_dir" ]; then
                    if [ -d "$script_dir/ojweb" ]; then
                        project_dir="$script_dir"
                    else
                        local temp_dir=$(cd "$script_dir/../.." 2>/dev/null && pwd || echo "")
                        if [ -n "$temp_dir" ] && [ -d "$temp_dir/ojweb" ]; then
                            project_dir="$temp_dir"
                        fi
                    fi
                fi
            fi
            
            if [ -z "$project_dir" ] || [ ! -d "$project_dir/ojweb" ]; then
                local current_dir=$(pwd)
                local search_dir="$current_dir"
                for i in {1..5}; do
                    if [ -d "$search_dir/ojweb" ]; then
                        project_dir="$search_dir"
                        break
                    fi
                    search_dir=$(cd "$search_dir/.." 2>/dev/null && pwd || echo "")
                    if [ "$search_dir" = "/" ] || [ -z "$search_dir" ]; then
                        break
                    fi
                done
            fi
            
            if [ -n "$project_dir" ] && [ -d "$project_dir/ojweb" ]; then
                WEB_MOUNT_ARGS=(
                    -v "$project_dir/ojweb/application:/ojweb/application"
                    -v "$project_dir/ojweb/config:/ojweb/config"
                    -v "$project_dir/ojweb/public:/ojweb/public"
                    -v "$project_dir/ojweb/route:/ojweb/route"
                    -v "$project_dir/ojweb/extend:/ojweb/extend"
                    -v "$project_dir/ojweb/vendor:/ojweb/vendor"
                    -v "$project_dir/ojweb/thinkphp:/ojweb/thinkphp"
                    -v "$project_dir/ojweb/backtask:/ojweb/backtask"
                    -v "$project_dir/ojweb/entrypoint.sh:/ojweb/entrypoint.sh"
                    -v "$project_dir/ojweb/dbinit.py:/ojweb/dbinit.py"
                    -v "$project_dir/deploy_files/SQL/:/SQL/"
                    -v "$project_dir/deploy_files/nginx_conf:/nginx_conf:ro"
                )
                
                local php_ini_source="$project_dir/deploy_files/build_php/php.ini-production"
                if [ -f "$php_ini_source" ]; then
                    WEB_MOUNT_ARGS+=(
                        -v "$php_ini_source:/usr/local/etc/php/conf.d/50-csgoj.ini:ro"
                    )
                    echo "🔧 开发模式：已启用源码目录挂载"
                    echo "   ✅ PHP 配置片段已挂载: $php_ini_source -> /usr/local/etc/php/conf.d/50-csgoj.ini (ro)"
                else
                    echo "🔧 开发模式：已启用源码目录挂载"
                    echo "   ⚠️  PHP 配置文件未找到: $php_ini_source（跳过挂载）"
                fi
            fi
        fi
        
        mkdir -p "$PATH_DATA/nginx/nginx_conf.d"
        mkdir -p "$PATH_DATA/var/www/$OJ_NAME"
        mkdir -p "$PATH_DATA/var/data/judge-$BELONG_TO"

        local OJWEB_WORK_MOUNT_ARGS=()
        if [ "${CSGOJ_OJWEB_SHARED_WORK:-1}" = "1" ]; then
            local ojweb_shared_root="$PATH_DATA/var/ojweb_work/$BELONG_TO"
            mkdir -p "$ojweb_shared_root/PROBLEM_EXPORT/EXPORT" \
                "$ojweb_shared_root/PROBLEM_EXPORT/FILE_TEMP" \
                "$ojweb_shared_root/PROBLEM_EXPORT/IMPORT_TEMP" \
                "$ojweb_shared_root/CONTEST_EXPORT/EXPORT" \
                "$ojweb_shared_root/CONTEST_EXPORT/FILE_TEMP" \
                "$ojweb_shared_root/CONTEST_EXPORT/IMPORT_TEMP" \
                "$ojweb_shared_root/CONTEST_SUMMARY/FILE_TEMP" \
                "$ojweb_shared_root/CONTEST_SUMMARY/SUMMARY" \
                "$ojweb_shared_root/CHUNK_TEMP" \
                "$ojweb_shared_root/CPC_CLIENT_RECORD"
            chmod -R 777 "$ojweb_shared_root" 2>/dev/null || true
            OJWEB_WORK_MOUNT_ARGS=(
                -v "$ojweb_shared_root/PROBLEM_EXPORT:/ojweb/PROBLEM_EXPORT"
                -v "$ojweb_shared_root/CONTEST_EXPORT:/ojweb/CONTEST_EXPORT"
                -v "$ojweb_shared_root/CONTEST_SUMMARY:/ojweb/CONTEST_SUMMARY"
                -v "$ojweb_shared_root/CHUNK_TEMP:/ojweb/CHUNK_TEMP"
                -v "$ojweb_shared_root/CPC_CLIENT_RECORD:/ojweb/CPC_CLIENT_RECORD"
            )
            echo "📂 /ojweb 工作目录共享卷: $ojweb_shared_root → 容器内 PROBLEM_EXPORT、CONTEST_EXPORT 等（BELONG_TO=$BELONG_TO）"
        fi
        
        local docker_run_output
        local env_args=(
            -e DB_HOSTNAME="$SQL_HOST"
            -e DB_DATABASE="${SQL_USER}_${BELONG_TO}"
            -e DB_USERNAME="$SQL_USER"
            -e DB_PASSWORD="$PASS_SQL_USER"
            -e DB_HOSTPORT="$PORT_OJ_DB"
            -e PORT_OJ="$PORT_OJ"
            -e OJ_SESSION="$OJ_NAME"
            -e OJ_NAME="$OJ_NAME"
            -e OJ_CDN="$OJ_CDN"
            -e OJ_MODE="$OJ_MODE"
            -e OJ_STATUS="$OJ_STATUS"
            -e OJ_STATIC="/var/www/public/$BELONG_TO"
            -e OJ_UPDATE_STATIC="$OJ_UPDATE_STATIC"
            -e BELONG_TO="$BELONG_TO"
            -e WEB_SSL="${WEB_SSL:-0}"
            -e WEB_SSL_CERT="${WEB_SSL_CERT:-}"
            -e WEB_SSL_KEY="${WEB_SSL_KEY:-}"
            -e WEB_SSL_SERVER_NAME="${WEB_SSL_SERVER_NAME:-}"
            -e "APP_TIMEZONE=${APP_TIMEZONE:-Asia/Shanghai}"
            -e "TZ=${APP_TIMEZONE:-Asia/Shanghai}"
            -e PROXY=
            -e HTTP_PROXY=
            -e HTTPS_PROXY=
            -e http_proxy=
            -e https_proxy=
            -e NO_PROXY=
            -e no_proxy=
            -e ALL_PROXY=
            -e all_proxy=
        )
        if [ -n "${CSGOJ_FIX_PERMS:-}" ]; then
            env_args+=(-e CSGOJ_FIX_PERMS="$CSGOJ_FIX_PERMS")
        fi
        if [ "$CSGOJ_DEV" = "1" ]; then
            env_args+=(-e CSGOJ_DEV=1)
        fi
        if [ -n "${BACKTASK_SITE_KEY:-}" ]; then
            env_args+=(-e "BACKTASK_SITE_KEY=$BACKTASK_SITE_KEY")
        elif [ -n "${BELONG_TO:-}" ] && [ -n "${OJ_NAME:-}" ] && [ "$BELONG_TO" != "$OJ_NAME" ]; then
            env_args+=(-e "BACKTASK_SITE_KEY=$BELONG_TO")
            echo "ℹ️  副实例未设 BACKTASK_SITE_KEY：使用 BELONG_TO=$BELONG_TO（与主实例 worker 认领键对齐）"
        fi
        if [ -n "${BELONG_TO:-}" ] && [ -n "${OJ_NAME:-}" ] && [ "$BELONG_TO" != "$OJ_NAME" ] \
            && [ "${CSGOJ_BACKTASK_ON_SECONDARY:-0}" != "1" ]; then
            env_args+=(-e CSGOJ_BACKTASK=0)
            echo "ℹ️  副实例 BELONG_TO=$BELONG_TO ≠ OJ_NAME=$OJ_NAME：CSGOJ_BACKTASK=0（worker 仅主实例 php-$BELONG_TO）"
        fi
        if [ "${CSGOJ_BACKTASK_ON_SECONDARY:-0}" = "1" ]; then
            env_args+=(-e CSGOJ_BACKTASK_ON_SECONDARY=1)
        fi


        local tz_mount_args=()
        if [ -f /etc/localtime ]; then
            tz_mount_args+=(-v /etc/localtime:/etc/localtime:ro)
        fi
        if [ -f /etc/timezone ]; then
            tz_mount_args+=(-v /etc/timezone:/etc/timezone:ro)
        fi

        docker_run_output=$(docker run --pull=never -dit $LINK_LOCAL \
            --name "php-$OJ_NAME" \
            "${env_args[@]}" \
            -v "$PATH_DATA/var/www:/var/www" \
            "${WEB_MOUNT_ARGS[@]}" \
            "${OJWEB_WORK_MOUNT_ARGS[@]}" \
            "${tz_mount_args[@]}" \
            -v "$PATH_DATA/var/data/judge-$BELONG_TO:/home/judge" \
            -v "$PATH_DATA/nginx/nginx_conf.d:/etc/nginx/conf.d" \
            --restart=unless-stopped \
            "$web_image" 2>&1)
        local docker_run_exit_code=$?
        sleep 1
        if ! docker ps --format "{{.Names}}" | grep -q "^php-$OJ_NAME$"; then
            echo "❌ OJ Web 容器启动失败"
            echo "   docker run 输出："
            echo "$docker_run_output" | head -10
            echo ""
            if docker ps -a --format "{{.Names}}" | grep -q "^php-$OJ_NAME$"; then
                echo "   容器已创建但未运行，查看日志："
                docker logs "php-$OJ_NAME" 2>&1 | tail -15
                echo ""
                echo "   尝试清理失败的容器..."
                docker rm -f "php-$OJ_NAME" >/dev/null 2>&1 || true
            fi
            echo "   提示："
            echo "   - 检查镜像是否存在: docker images | grep ccpcoj-web"
            echo "   - 检查参数是否正确: SQL_HOST=$SQL_HOST, PORT_OJ_DB=$PORT_OJ_DB"
            echo "   - 检查目录权限: $PATH_DATA"
            return 1
        fi
        
        docker restart nginx-server >/dev/null 2>&1 || true
        
        echo "✅ OJ Web 容器启动成功"
    fi
    echo ""
}

start_nginx() {
    local NGINX_IMAGE_VERSION="1.29.7-alpine"
    local NGINX_IMAGE="nginx:${NGINX_IMAGE_VERSION}"
    
    local NGINX_ENTRYPOINT_QUIET_LOGS="${NGINX_ENTRYPOINT_QUIET_LOGS:-1}"
    local NGINX_ULIMIT_NOFILE="${NGINX_ULIMIT_NOFILE:-65535}"
    local NGINX_LOG_MAX_SIZE="${NGINX_LOG_MAX_SIZE:-20m}"
    local NGINX_LOG_MAX_FILE="${NGINX_LOG_MAX_FILE:-5}"
    local NGINX_PIDS_LIMIT="${NGINX_PIDS_LIMIT:-4096}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  初始化 Nginx"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -n "$(docker ps -aq -f name=^nginx-server$)" ]; then
        echo "✅ Nginx 容器已存在"
    else
        if [ -z "${NGINX_PORT_RANGES:-}" ]; then
            NGINX_PORT_RANGES="-p $PORT_OJ:$PORT_OJ -p $PORT_MYADMIN:$PORT_MYADMIN"
        fi
        local nginx_port_grep_pattern=""
        local __np_list=()
        read -ra __np_tok <<< "$NGINX_PORT_RANGES"
        local __np_i=0
        while [ $__np_i -lt ${#__np_tok[@]} ]; do
            if [ "${__np_tok[$__np_i]}" = "-p" ]; then
                ((__np_i++)) || true
                [ $__np_i -lt ${#__np_tok[@]} ] || break
                local __np_spec="${__np_tok[$__np_i]}"
                local __np_host
                __np_host=$(printf '%s' "$__np_spec" | awk -F: '{print $(NF-1)}')
                if [[ "$__np_host" =~ ^[0-9]+-[0-9]+$ ]]; then
                    local __np_lo="${__np_host%-*}" __np_hi="${__np_host#*-}"
                    if [ "$__np_lo" -le "$__np_hi" ] 2>/dev/null && [ "$((__np_hi - __np_lo))" -le 2048 ]; then
                        local __np_p
                        for ((__np_p=__np_lo; __np_p<=__np_hi; __np_p++)); do
                            __np_list+=("$__np_p")
                        done
                    fi
                elif [[ "$__np_host" =~ ^[0-9]+$ ]]; then
                    __np_list+=("$__np_host")
                fi
            fi
            ((__np_i++)) || true
        done
        if [ ${#__np_list[@]} -gt 0 ]; then
            mapfile -t __np_sorted < <(printf '%s\n' "${__np_list[@]}" | sort -nu)
            local __np_sep=''
            for __np_one in "${__np_sorted[@]}"; do
                nginx_port_grep_pattern+="${__np_sep}${__np_one}"
                __np_sep='|'
            done
        fi
        if [ -z "$nginx_port_grep_pattern" ]; then
            nginx_port_grep_pattern="${PORT_OJ}|${PORT_MYADMIN}"
        fi
        
        PUBLIC_MOUNT=""
        if [ "$CSGOJ_DEV" = "1" ]; then
            local project_dir=""
            
            if [ -n "$SCRIPT_DIR" ]; then
                local temp_dir=$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd || echo "")
                if [ -n "$temp_dir" ] && [ -d "$temp_dir/ojweb/public" ]; then
                    project_dir="$temp_dir"
                fi
            fi
            
            if [ -z "$project_dir" ] || [ ! -d "$project_dir/ojweb/public" ]; then
                local script_dir=""
                if [ -n "${BASH_SOURCE[0]}" ]; then
                    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")
                fi
                if [ -z "$script_dir" ] && [ -n "$0" ]; then
                    script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")
                fi
                
                if [ -n "$script_dir" ]; then
                    if [ -d "$script_dir/ojweb/public" ]; then
                        project_dir="$script_dir"
                    else
                        local temp_dir=$(cd "$script_dir/../.." 2>/dev/null && pwd || echo "")
                        if [ -n "$temp_dir" ] && [ -d "$temp_dir/ojweb/public" ]; then
                            project_dir="$temp_dir"
                        fi
                    fi
                fi
            fi
            
            if [ -z "$project_dir" ] || [ ! -d "$project_dir/ojweb/public" ]; then
                local current_dir=$(pwd)
                local search_dir="$current_dir"
                for i in {1..5}; do
                    if [ -d "$search_dir/ojweb/public" ]; then
                        project_dir="$search_dir"
                        break
                    fi
                    search_dir=$(cd "$search_dir/.." 2>/dev/null && pwd || echo "")
                    if [ "$search_dir" = "/" ] || [ -z "$search_dir" ]; then
                        break
                    fi
                done
            fi
            
            if [ -n "$project_dir" ] && [ -d "$project_dir/ojweb/public" ]; then
                PUBLIC_MOUNT="-v $project_dir/ojweb/public:/var/www/baseoj/public"
                echo "🔧 开发模式：已启用源码目录挂载 ($project_dir/ojweb/public)"
            fi
        fi
        
        mkdir -p "$PATH_DATA/nginx/nginx_conf.d"
        mkdir -p "$PATH_DATA/nginx/attach"
        mkdir -p "$PATH_DATA/nginx/base"
        mkdir -p "$PATH_DATA/var/log/nginx"
        mkdir -p "$PATH_DATA/dataspace"
        mkdir -p "$PATH_DATA/var/www"

        local base_conf_dst="$PATH_DATA/nginx/base/nginx_base.conf"
        local base_conf_src=""

        local candidates=(
            "$SCRIPT_DIR/../nginx_conf/nginx_base.conf"
            "$SCRIPT_DIR/deploy_files/nginx_conf/nginx_base.conf"
            "$(pwd)/deploy_files/nginx_conf/nginx_base.conf"
        )
        for p in "${candidates[@]}"; do
            if [ -f "$p" ]; then
                base_conf_src="$p"
                break
            fi
        done

        if [ -n "$base_conf_src" ]; then
            cp -f "$base_conf_src" "$base_conf_dst"
        elif [ ! -f "$base_conf_dst" ]; then
            cat > "$base_conf_dst" <<'EOF'
# Nginx 基础配置（http 作用域 include），不包含任何 server/upstream/location 业务逻辑
error_log /dev/stderr warn;
access_log off;
server_tokens off;
open_file_cache max=10000 inactive=30s;
open_file_cache_valid 60s;
open_file_cache_min_uses 2;
open_file_cache_errors on;
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 1024;
gzip_http_version 1.1;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/javascript
    application/json
    application/xml
    application/xml+rss
    image/svg+xml;
gzip_disable "msie6";
EOF
        fi

        cp -f "$base_conf_dst" "$PATH_DATA/nginx/nginx_conf.d/00-nginx-base.conf"
        
        local docker_run_output
        
        local docker_run_args=(
            "run"
            "--name" "nginx-server"
            "--init"
            "--stop-signal" "SIGQUIT"
            "--restart=unless-stopped"
            "--pids-limit" "$NGINX_PIDS_LIMIT"
            "--security-opt" "no-new-privileges:true"
            "--ulimit" "nofile=${NGINX_ULIMIT_NOFILE}:${NGINX_ULIMIT_NOFILE}"
            "--log-driver" "json-file"
            "--log-opt" "max-size=${NGINX_LOG_MAX_SIZE}"
            "--log-opt" "max-file=${NGINX_LOG_MAX_FILE}"
            "--log-opt" "mode=non-blocking"
            "--log-opt" "max-buffer-size=4m"
            "-e" "NGINX_ENTRYPOINT_QUIET_LOGS=${NGINX_ENTRYPOINT_QUIET_LOGS}"
        )
        
        if [ -n "${LINK_LOCAL:-}" ]; then
            read -ra link_local_args <<< "$LINK_LOCAL"
            docker_run_args+=("${link_local_args[@]}")
        fi
        
        if [ -n "${NGINX_PORT_RANGES:-}" ]; then
            read -ra port_range_args <<< "$NGINX_PORT_RANGES"
            docker_run_args+=("${port_range_args[@]}")
        fi
        
        if [ -n "${NGINX_EXTRA_RUN_ARGS:-}" ]; then
            read -ra extra_run_args <<< "$NGINX_EXTRA_RUN_ARGS"
            docker_run_args+=("${extra_run_args[@]}")
        fi
        
        docker_run_args+=(
            "-v" "$PATH_DATA/var/www:/var/www"
        )
        
        if [ -n "${PUBLIC_MOUNT:-}" ]; then
            read -ra public_mount_args <<< "$PUBLIC_MOUNT"
            docker_run_args+=("${public_mount_args[@]}")
        fi

        if [ -n "${NGINX_EXTRA_MOUNTS:-}" ]; then
            read -ra extra_mount_args <<< "$NGINX_EXTRA_MOUNTS"
            docker_run_args+=("${extra_mount_args[@]}")
        fi
        
        docker_run_args+=(
            "-v" "$PATH_DATA/dataspace:$PATH_DATA/dataspace"
            "-v" "$PATH_DATA/var/log/nginx:/var/log/nginx"
            "-v" "$PATH_DATA/nginx/nginx_conf.d:/etc/nginx/conf.d:ro"
            "-v" "$PATH_DATA/nginx/attach:/etc/nginx/attach:ro"
            "-d"
            "$NGINX_IMAGE"
        )
        
        local docker_run_log
        docker_run_log=$(mktemp)
        docker "${docker_run_args[@]}" 2>&1 | tee "$docker_run_log"
        local docker_run_exit_code=$?
        if [ -f "$docker_run_log" ]; then
            docker_run_output=$(sed -n '1,120p' "$docker_run_log")
            rm -f "$docker_run_log"
        fi
        
        if [ $docker_run_exit_code -ne 0 ]; then
            echo "❌ Nginx 容器启动失败（docker run 退出码: $docker_run_exit_code）"
            echo "   docker run 输出："
            echo "$docker_run_output"
            echo ""
            if docker ps -a --format "{{.Names}}" | grep -q "^nginx-server$"; then
                echo "   容器已创建但未运行，查看容器状态："
                docker inspect nginx-server --format '状态: {{.State.Status}}' 2>/dev/null || echo "   无法获取容器状态"
                local container_error=$(docker inspect nginx-server --format '{{.State.Error}}' 2>/dev/null || echo "")
                if [ -n "$container_error" ]; then
                    echo "   错误信息: $container_error"
                fi
                echo ""
                echo "   尝试清理失败的容器..."
                docker rm -f "nginx-server" >/dev/null 2>&1 || true
            fi
            echo "   提示："
            echo "   - 检查镜像是否存在: docker images | grep nginx"
            echo "   - 检查端口是否被占用: netstat -tuln | grep -E '${nginx_port_grep_pattern}'"
            echo "   - 检查目录权限: $PATH_DATA"
            return 1
        fi
        
        sleep 1
        if ! docker ps --format "{{.Names}}" | grep -q "^nginx-server$"; then
            echo "❌ Nginx 容器启动失败（容器未运行）"
            echo "   docker run 输出："
            echo "$docker_run_output"
            echo ""
            if docker ps -a --format "{{.Names}}" | grep -q "^nginx-server$"; then
                echo "   容器已创建但未运行，查看容器状态："
                docker inspect nginx-server --format '状态: {{.State.Status}}' 2>/dev/null || echo "   无法获取容器状态"
                local container_error=$(docker inspect nginx-server --format '{{.State.Error}}' 2>/dev/null || echo "")
                if [ -n "$container_error" ]; then
                    echo "   错误信息: $container_error"
                fi
                echo ""
                echo "   查看容器日志："
                docker logs "nginx-server" 2>&1 | tail -15 || echo "   无法获取日志"
                echo ""
                echo "   尝试清理失败的容器..."
                docker rm -f "nginx-server" >/dev/null 2>&1 || true
            fi
            echo "   提示："
            echo "   - 检查镜像是否存在: docker images | grep nginx"
            echo "   - 检查端口是否被占用: netstat -tuln | grep -E '${nginx_port_grep_pattern}'"
            echo "   - 检查目录权限: $PATH_DATA"
            return 1
        fi
        
        echo "✅ Nginx 容器启动成功"
    fi
    echo ""
}

show_help() {
    cat << EOF
CSGOJ 评测机启动脚本

使用方法:
  bash start_judge2.sh [选项...]

必需参数:
  --CSGOJ_SERVER_BASE_URL=<地址>     OJ Web 服务器地址
  --CSGOJ_SERVER_USERNAME=<用户名>   评测机用户名
  --CSGOJ_SERVER_PASSWORD=<密码>     评测机密码
  --PATH_DATA=<路径>                 数据目录绝对路径

可选参数:
  --JUDGE_POD_COUNT=<数量>           启动的 pod 数量（默认: 1）
  --restart-all                      重启所有 pod（docker restart，保持容器不变）
  --rebuild-all                      重开所有 pod（删除并重新创建，需要提供启动参数）
  --remove-all, --delete-all         删除所有 pod（仅删除容器，不重新创建）
  --noninteractive, --no-interactive  非交互模式（参数缺失时直接报错，不进入交互补全）
  --OJ_NAME=<名称>                  OJ 名称（默认: ccpc）
  --CSGOJ_VERSION=<版本>            Docker 镜像版本（默认: latest）
  --DOCKER_NET_NAME=<名称>           Docker 网络名称（默认: csgoj_net）
  --DOCKER_PULL_NEW=<0|1>           是否拉取最新镜像（默认: 1）
  
CPU 绑核/实验参数（可选）:
  --CPUSET_CPUS=<列表>              强制所有 pod 使用同一段 cpuset（会覆盖 offset/自动查找）
                                   示例：--CPUSET_CPUS=2-5 或 --CPUSET_CPUS=2,3,4,5

示例:
  # 启动单个评测机 pod
  bash start_judge2.sh \\
      --CSGOJ_SERVER_BASE_URL=http://192.168.1.100:20080 \\
      --CSGOJ_SERVER_USERNAME=judger \\
      --CSGOJ_SERVER_PASSWORD=123456

  # 启动多个评测机 pod
  bash start_judge2.sh \\
      --CSGOJ_SERVER_BASE_URL=http://oj.example.com:20080 \\
      --CSGOJ_SERVER_USERNAME=judger \\
      --CSGOJ_SERVER_PASSWORD=123456 \\
      --JUDGE_POD_COUNT=4
  
  # 重启所有评测机 pod（docker restart）
  bash start_judge2.sh \\
      --restart-all

  # 重开所有评测机 pod（删除并重新创建）
  bash start_judge2.sh \\
      --CSGOJ_SERVER_BASE_URL=http://192.168.1.100:20080 \\
      --CSGOJ_SERVER_USERNAME=judger \\
      --CSGOJ_SERVER_PASSWORD=123456 \\
      --rebuild-all

  # 删除所有评测机 pod（仅删除，不重新创建）
  bash start_judge2.sh \\
      --remove-all

注意:
  • 资源（CPU、内存）将根据系统资源自动计算和分配
  • 评测机密码需要在 Web 管理界面设置后获取
  • CSGOJ_SERVER_BASE_URL 必须使用评测机容器能访问的 IP 或域名
  • 不要使用 localhost 或 127.0.0.1（评测机容器内无法访问宿主机 localhost）
  • 如果评测机和 Web 在同一台机器，使用服务器的内网或外网 IP
  • --restart-all: 仅重启现有容器（docker restart），不需要启动参数
  • --rebuild-all: 删除所有容器并重新创建，需要提供启动参数
  • --remove-all: 仅删除所有容器，不重新创建，不需要启动参数
  • 默认交互模式：必要参数缺失时进入交互式补全
  • 非交互模式：使用 --noninteractive 时，参数缺失直接报错

EOF
}





convert_memory_to_gb() {
    local mem_str="$1"
    local mem_value=$(echo "$mem_str" | sed 's/[^0-9.]//g')
    local mem_unit=$(echo "$mem_str" | sed 's/[0-9.]//g' | tr '[:upper:]' '[:lower:]')
    
    case "$mem_unit" in
        g|gb|gigabyte|gigabytes)
            echo "${mem_value%.*}"
            ;;
        m|mb|megabyte|megabytes)
            echo "$((mem_value / 1024))"
            ;;
        *)
            echo "${mem_value%.*}"
            ;;
    esac
}

get_host_mem_total_gb() {
    local mem_kb=""
    if [ -r /proc/meminfo ]; then
        mem_kb=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
    fi
    if [ -n "$mem_kb" ] && [[ "$mem_kb" =~ ^[0-9]+$ ]] && [ "$mem_kb" -gt 0 ]; then
        echo $((mem_kb / 1024 / 1024))
        return 0
    fi
    local gb=""
    if command -v free >/dev/null 2>&1; then
        gb=$(command free -g 2>/dev/null | awk '/^Mem:/{print $2; exit}')
    fi
    if [ -n "$gb" ] && [[ "$gb" =~ ^[0-9]+$ ]]; then
        echo "$gb"
        return 0
    fi
    echo 0
    return 1
}

calculate_cpu_per_pod() {
    local target_pod_count=$1
    local total_cpus=$(nproc)
    
    if [ $target_pod_count -eq 1 ] && [ $total_cpus -lt 8 ]; then
        local available_after_offset=$((total_cpus - 2))
        if [ $available_after_offset -ge 4 ]; then
            echo $available_after_offset
        else
            echo 4
        fi
    else
        echo 4
    fi
}

calculate_memory_per_pod() {
    echo 4
}

calculate_cpu_offset() {
    local target_pod_count=$1
    local cpus_per_pod=$2
    local total_cpus=$(nproc)
    
    if [ $target_pod_count -eq 1 ] && [ $total_cpus -lt 8 ]; then
        local available_after_offset=$((total_cpus - 2))
        if [ $available_after_offset -ge 4 ]; then
            echo 2
        else
            local offset=$((total_cpus - 4))
            if [ $offset -lt 0 ]; then
                echo 0
            else
                echo $offset
            fi
        fi
    else
        echo 2
    fi
}

validate_and_calculate_resources() {
    local target_pod_count=$1
    
    local auto_cpus=$(calculate_cpu_per_pod $target_pod_count)
    local auto_memory_gb=$(calculate_memory_per_pod $target_pod_count)
    
    JUDGE_DOCKER_CPUS=$auto_cpus
    JUDGE_DOCKER_MEMORY="${auto_memory_gb}g"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  自动资源配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local total_mem_gb
    total_mem_gb=$(get_host_mem_total_gb) || total_mem_gb=0

    echo "  系统资源:"
    echo "    CPU: $(nproc) 逻辑核心"
    if [[ "$total_mem_gb" =~ ^[0-9]+$ ]] && [ "$total_mem_gb" -gt 0 ]; then
        echo "    内存: ${total_mem_gb}GB"
    else
        echo "    内存: （无法识别，请检查 /proc/meminfo 或 free 命令）"
    fi
    echo ""
    
    display_cpu_bindings
    echo ""
    
    echo "  目标 pod 数量: ${target_pod_count}"
    echo "  自动配置（每个 pod）:"
    echo "    CPU: ${auto_cpus} 核心"
    echo "    内存: ${auto_memory_gb}GB (+ 1GB SHM = $(($auto_memory_gb + 1))GB 总计)"
    echo ""
    
    local total_cpus=$(nproc)
    if ! [[ "$total_mem_gb" =~ ^[0-9]+$ ]] || [ "$total_mem_gb" -lt 1 ]; then
        echo "❌ 错误: 无法识别系统内存大小"
        echo "   请确认 /proc/meminfo 可读，且未对 free 设置 -L/--line 等别名包装"
        exit 1
    fi
    local reserved_mem_gb=2
    local max_mem=$((total_mem_gb - reserved_mem_gb))
    
    local needed_cpus=$((target_pod_count * auto_cpus))
    local shm_size_gb=1
    local needed_mem=$((target_pod_count * (auto_memory_gb + shm_size_gb)))
    
    local max_pods_by_cpu=0
    local used_cpu_count=0
    local cpu_reserved_offset=2
    local available_cpus_for_pods=0
    if [ $target_pod_count -eq 1 ] && [ $total_cpus -lt 8 ]; then
        max_pods_by_cpu=1
        available_cpus_for_pods=$total_cpus
    else
        if [ -n "$CPUSET_CPUS" ]; then
            max_pods_by_cpu=$target_pod_count
            available_cpus_for_pods=$total_cpus
        else
            get_used_cpus
            used_cpu_count=${#USED_CPUS[@]}
            
            local fixed_cpus_per_pod=$auto_cpus
            
            available_cpus_for_pods=$((total_cpus - cpu_reserved_offset - used_cpu_count))
            if [ $fixed_cpus_per_pod -gt 0 ] && [ $available_cpus_for_pods -gt 0 ]; then
                max_pods_by_cpu=$((available_cpus_for_pods / fixed_cpus_per_pod))
            fi
        fi
    fi
    
    local max_pods_by_mem=0
    if [ $((auto_memory_gb + shm_size_gb)) -gt 0 ]; then
        max_pods_by_mem=$((max_mem / (auto_memory_gb + shm_size_gb)))
    fi
    
    local max_pods=0
    if [ $max_pods_by_cpu -lt $max_pods_by_mem ]; then
        max_pods=$max_pods_by_cpu
    else
        max_pods=$max_pods_by_mem
    fi
    
    if [ $max_pods -lt 1 ]; then
        local cpu_insufficient=0
        local mem_insufficient=0
        [ "$max_pods_by_cpu" -lt 1 ] && cpu_insufficient=1
        [ "$max_pods_by_mem" -lt 1 ] && mem_insufficient=1

        echo "❌ 错误: 无法启动任何评测机 pod"
        if [ "$cpu_insufficient" -eq 1 ] && [ "$mem_insufficient" -eq 1 ]; then
            echo "   原因: CPU 与内存均不足"
        elif [ "$cpu_insufficient" -eq 1 ]; then
            echo "   原因: CPU 不足"
        elif [ "$mem_insufficient" -eq 1 ]; then
            echo "   原因: 内存不足"
        else
            echo "   原因: 系统资源不满足最低要求"
        fi
        echo ""

        if [ "$cpu_insufficient" -eq 1 ]; then
            echo "   【CPU】"
            echo "     逻辑核心总数: ${total_cpus}"
            if [ -n "$CPUSET_CPUS" ]; then
                echo "     已指定 --CPUSET_CPUS=${CPUSET_CPUS}（脚本未按核心数限制 pod 数，请检查其它限制）"
            elif [ $target_pod_count -eq 1 ] && [ $total_cpus -lt 8 ]; then
                echo "     单 pod 低配模式: 总核心 < 8，理论上可启动 1 个 pod"
            else
                echo "     预留核心（偏移）: ${cpu_reserved_offset}"
                echo "     已被其它评测机容器占用: ${used_cpu_count}"
                echo "     可用于新 pod: ${available_cpus_for_pods}（每个 pod 需 ${auto_cpus} 核）"
                echo "     目标 ${target_pod_count} 个 pod 约需 ${needed_cpus} 核"
            fi
            echo ""
        fi

        if [ "$mem_insufficient" -eq 1 ]; then
            echo "   【内存】"
            echo "     总内存: ${total_mem_gb}GB，预留 ${reserved_mem_gb}GB 后可用约 ${max_mem}GB"
            echo "     每个 pod 约需 $(($auto_memory_gb + shm_size_gb))GB（${auto_memory_gb}GB + ${shm_size_gb}GB SHM）"
            echo "     目标 ${target_pod_count} 个 pod 约需 ${needed_mem}GB"
            echo ""
        fi

        echo "   建议使用 CPU / 内存更大的服务器，或减少 --JUDGE_POD_COUNT"
        exit 1
    elif [ $max_pods -lt $target_pod_count ]; then
        local shortage=$((target_pod_count - max_pods))
        local limit_reason=""
        if [ "$max_pods_by_cpu" -lt "$max_pods_by_mem" ]; then
            limit_reason="CPU 不足"
        elif [ "$max_pods_by_mem" -lt "$max_pods_by_cpu" ]; then
            limit_reason="内存不足"
        else
            limit_reason="CPU 与内存均不足"
        fi
        echo "⚠️  警告: ${limit_reason}，只能启动 ${max_pods} 个 pod（目标: ${target_pod_count}）"
        echo "   缺少 ${shortage} 个 pod 的资源（CPU 最多 ${max_pods_by_cpu} 个，内存最多 ${max_pods_by_mem} 个）"
        echo "   每个 pod: ${auto_cpus} 核 CPU，$(($auto_memory_gb + shm_size_gb))GB 内存（含 SHM）"
        echo ""
        
        local actual_count=$max_pods
        if [ $actual_count -lt 1 ]; then
            actual_count=1
        fi
        
        echo "💡 将自动调整为启动 ${actual_count} 个 pod"
        JUDGE_POD_COUNT=$actual_count
        
        read -p "是否继续？(y/n, 默认: y): " confirm
        confirm=${confirm:-y}
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "已取消启动"
            exit 0
        fi
    else
        echo "✅ 资源充足，可以启动 ${target_pod_count} 个 pod"
    fi
    
    echo ""
}


get_all_judge_cpu_bindings() {
    local all_judge_containers=$(docker ps -a --filter "name=judge-" --format "{{.Names}}" 2>/dev/null || true)
    local bindings=()
    
    for container in $all_judge_containers; do
        local cpuset=$(docker inspect "$container" --format='{{.HostConfig.CpusetCpus}}' 2>/dev/null || echo "")
        
        if [ -n "$cpuset" ] && [ "$cpuset" != "<no value>" ]; then
            bindings+=("$container:$cpuset")
        fi
    done
    
    for binding in "${bindings[@]}"; do
        echo "$binding"
    done
}

parse_cpu_list() {
    local cpu_list="$1"
    local cpus=()
    
    if [[ "$cpu_list" == *","* ]]; then
        IFS=',' read -ra cpu_parts <<< "$cpu_list"
        for part in "${cpu_parts[@]}"; do
            if [[ "$part" == *"-"* ]]; then
                local start=$(echo "$part" | cut -d'-' -f1)
                local end=$(echo "$part" | cut -d'-' -f2)
                for ((cpu=start; cpu<=end; cpu++)); do
                    cpus+=($cpu)
                done
            else
                cpus+=($part)
            fi
        done
    elif [[ "$cpu_list" == *"-"* ]]; then
        local start=$(echo "$cpu_list" | cut -d'-' -f1)
        local end=$(echo "$cpu_list" | cut -d'-' -f2)
        for ((cpu=start; cpu<=end; cpu++)); do
            cpus+=($cpu)
        done
    else
        cpus+=($cpu_list)
    fi
    
    printf '%s\n' "${cpus[@]}" | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

get_used_cpus() {
    local bindings=$(get_all_judge_cpu_bindings)
    local all_used_cpus=()
    
    while IFS= read -r binding; do
        if [ -z "$binding" ]; then
            continue
        fi
        
        local container_name=$(echo "$binding" | cut -d':' -f1)
        local cpu_list=$(echo "$binding" | cut -d':' -f2)
        
        local parsed_cpus=($(parse_cpu_list "$cpu_list"))
        all_used_cpus+=("${parsed_cpus[@]}")
    done <<< "$bindings"
    
    USED_CPUS=($(printf '%s\n' "${all_used_cpus[@]}" | sort -n | uniq))
}

find_available_cpu_range() {
    local needed_cpus=$1
    local cpu_offset=$2
    local total_cpus=$(nproc)
    
    get_used_cpus
    
    declare -A used_cpu_map
    for cpu in "${USED_CPUS[@]}"; do
        used_cpu_map[$cpu]=1
    done
    
    local found_start=-1
    local found_count=0
    
    for ((cpu=cpu_offset; cpu<total_cpus; cpu++)); do
        if [ -z "${used_cpu_map[$cpu]}" ]; then
            if [ $found_start -eq -1 ]; then
                found_start=$cpu
                found_count=1
            else
                ((found_count++))
            fi
            
            if [ $found_count -eq $needed_cpus ]; then
                if [ $needed_cpus -eq 1 ]; then
                    echo "$found_start"
                else
                    local cpu_end=$((found_start + needed_cpus - 1))
                    echo "$found_start-$cpu_end"
                fi
                return 0
            fi
        else
            found_start=-1
            found_count=0
        fi
    done
    
    local found_cpus=()
    for ((cpu=cpu_offset; cpu<total_cpus && ${#found_cpus[@]} -lt needed_cpus; cpu++)); do
        if [ -z "${used_cpu_map[$cpu]}" ]; then
            found_cpus+=($cpu)
        fi
    done
    
    if [ ${#found_cpus[@]} -eq $needed_cpus ]; then
        local IFS=','
        echo "${found_cpus[*]}"
        unset IFS
        return 0
    fi
    
    return 1
}

display_cpu_bindings() {
    local bindings=$(get_all_judge_cpu_bindings)
    
    if [ -z "$bindings" ]; then
        echo "  当前没有评测机容器绑定 CPU"
        return
    fi
    
    echo "  当前评测机 CPU 绑核情况:"
    while IFS= read -r binding; do
        if [ -z "$binding" ]; then
            continue
        fi
        
        local container_name=$(echo "$binding" | cut -d':' -f1)
        local cpu_list=$(echo "$binding" | cut -d':' -f2)
        echo "    $container_name: $cpu_list"
    done <<< "$bindings"
}


find_available_pod_indices() {
    local target_count=$1
    local existing_indices=()
    
    local existing_containers=$(docker ps -a --filter "name=judge-$OJ_NAME" --format "{{.Names}}" 2>/dev/null || true)
    
    for container in $existing_containers; do
        if [[ $container =~ judge-$OJ_NAME-([0-9]+)$ ]]; then
            existing_indices+=("${BASH_REMATCH[1]}")
        elif [[ $container == judge-$OJ_NAME ]]; then
            existing_indices+=("0")
        fi
    done
    
    IFS=$'\n' sorted_indices=($(sort -n <<<"${existing_indices[*]}"))
    unset IFS
    
    local available_indices=()
    local current_idx=0
    
    for existing_idx in "${sorted_indices[@]}"; do
        while [ $current_idx -lt $existing_idx ] && [ ${#available_indices[@]} -lt $target_count ]; do
            available_indices+=($current_idx)
            ((current_idx++))
        done
        if [ ${#available_indices[@]} -ge $target_count ]; then
            break
        fi
        ((current_idx=$existing_idx+1))
    done
    
    while [ ${#available_indices[@]} -lt $target_count ]; do
        available_indices+=($current_idx)
        ((current_idx++))
    done
    
    echo "${available_indices[@]}"
}

restart_all_judge_pods() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  重启所有评测机 pod"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local containers=$(docker ps -a --filter "name=judge-$OJ_NAME" --format "{{.Names}}" 2>/dev/null || true)
    
    if [ -z "$containers" ]; then
        echo "  没有找到现有的 pod"
        echo ""
        return
    fi
    
    for container in $containers; do
        echo "  重启: $container"
        docker restart "$container" >/dev/null 2>&1 || true
    done
    
    echo "  完成"
    echo ""
}

rebuild_all_judge_pods() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  重开所有评测机 pod"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local containers=$(docker ps -a --filter "name=judge-$OJ_NAME" --format "{{.Names}}" 2>/dev/null || true)
    
    if [ -z "$containers" ]; then
        echo "  没有找到现有的 pod"
        echo ""
        return
    fi
    
    for container in $containers; do
        echo "  停止并删除: $container"
        docker stop "$container" >/dev/null 2>&1 || true
        docker rm "$container" >/dev/null 2>&1 || true
    done
    
    echo "  完成"
    echo ""
}

remove_all_judge_pods() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  删除所有评测机 pod"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local containers=$(docker ps -a --filter "name=judge-$OJ_NAME" --format "{{.Names}}" 2>/dev/null || true)
    
    if [ -z "$containers" ]; then
        echo "  没有找到现有的 pod"
        echo ""
        return
    fi
    
    for container in $containers; do
        echo "  删除: $container"
        docker stop "$container" >/dev/null 2>&1 || true
        docker rm "$container" >/dev/null 2>&1 || true
    done
    
    echo "  完成"
    echo ""
}

start_single_pod() {
    local pod_index=$1
    local cpus=$2
    local memory=$3
    local cpu_offset=$4
    
    if [ $pod_index -eq 0 ] && [ $JUDGE_POD_COUNT -eq 1 ]; then
        CONTAINER_NAME="judge-$OJ_NAME"
    else
        CONTAINER_NAME="judge-$OJ_NAME-$pod_index"
    fi
    
    if [ -n "$(docker ps -a -q -f name=^${CONTAINER_NAME}$)" ]; then
        echo "  ⏭️  跳过: $CONTAINER_NAME 已存在"
        return
    fi
    
    mkdir -p "$PATH_DATA/var/data/judge-$OJ_NAME/data"
    mkdir -p "$PATH_DATA/var/data/judge-$OJ_NAME/code"
    
    if [ $pod_index -eq 0 ] && [ $JUDGE_POD_COUNT -eq 1 ]; then
        LOG_DIR_NAME="judger-$OJ_NAME"
    else
        LOG_DIR_NAME="judger-$OJ_NAME-$pod_index"
    fi
    
    local log_dir_path="$PATH_DATA/var/log/judger/$LOG_DIR_NAME"
    mkdir -p "$log_dir_path"
    
    chmod 755 "$log_dir_path" 2>/dev/null || true
    
    local pod_cpuset_cpus=""
    CPUSET_CONFIG=""
    if [ "$PROVIDED_CPUSET_CPUS" = "true" ] && [ -n "$CPUSET_CPUS" ]; then
        pod_cpuset_cpus="$CPUSET_CPUS"
        CPUSET_CONFIG="--cpuset-cpus=$pod_cpuset_cpus"
        echo "  🔹 CPU 绑定: 强制使用 $pod_cpuset_cpus（所有 pod 相同，来自 --CPUSET_CPUS）"
    elif [ $cpu_offset -ge 0 ]; then
        local total_cpus=$(nproc)
        
        local available_cpu_range
        available_cpu_range=$(find_available_cpu_range $cpus $cpu_offset)
        
        if [ $? -ne 0 ] || [ -z "$available_cpu_range" ]; then
            echo "  ❌ 错误: 无法为 Pod $pod_index 找到足够的可用 CPU 核心"
            echo "     需要核心数: $cpus"
            echo "     系统CPU总数: $total_cpus (0-$((total_cpus - 1)))"
            echo "     起始搜索位置: $cpu_offset"
            echo ""
            
            echo "  当前 CPU 绑核情况:"
            display_cpu_bindings
            echo ""
            
            echo "💡 建议:"
            echo "   1. 减少 pod 数量"
            echo "   2. 减少每个 pod 的 CPU 数量"
            echo "   3. 删除其他评测机容器释放 CPU 核心"
            echo "   4. 使用更大的系统"
            return 1
        fi
        
        pod_cpuset_cpus="$available_cpu_range"
        CPUSET_CONFIG="--cpuset-cpus=$pod_cpuset_cpus"
        
        local parsed_cpus=($(parse_cpu_list "$available_cpu_range"))
        local cpu_count=${#parsed_cpus[@]}
        if [ $cpu_count -eq 1 ]; then
            echo "  🔹 CPU 绑定: 逻辑核心 ${parsed_cpus[0]} (共 1 个核心)"
        else
            local cpu_start=${parsed_cpus[0]}
            local cpu_end=${parsed_cpus[$((cpu_count - 1))]}
            if [ $cpu_end -eq $((cpu_start + cpu_count - 1)) ]; then
                echo "  🔹 CPU 绑定: 逻辑核心 $cpu_start-$cpu_end (共 $cpu_count 个核心)"
            else
                echo "  🔹 CPU 绑定: 逻辑核心 $pod_cpuset_cpus (共 $cpu_count 个核心，非连续)"
            fi
        fi
    else
        echo "  🔹 CPU 绑定: 未指定（使用系统自动分配）"
    fi
    
    JUDGE_MOUNT=""
    if [ "$CSGOJ_DEV" = "1" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  🔧 检测到开发模式（CSGOJ_DEV=1）"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        local project_dir=""
        
        if [ -n "$SCRIPT_DIR" ]; then
            local temp_dir=$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd || echo "")
            if [ -n "$temp_dir" ] && [ -d "$temp_dir/deploy_files/judge2/core" ]; then
                project_dir="$temp_dir"
            fi
        fi
        
        if [ -z "$project_dir" ] || [ ! -d "$project_dir/deploy_files/judge2/core" ]; then
            local script_dir=""
            if [ -n "${BASH_SOURCE[0]}" ]; then
                script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")
            fi
            if [ -z "$script_dir" ] && [ -n "$0" ]; then
                script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")
            fi
            
            if [ -n "$script_dir" ]; then
                if [ -d "$script_dir/deploy_files/judge2/core" ]; then
                    project_dir="$script_dir"
                else
                    local temp_dir=$(cd "$script_dir/../.." 2>/dev/null && pwd || echo "")
                    if [ -n "$temp_dir" ] && [ -d "$temp_dir/deploy_files/judge2/core" ]; then
                        project_dir="$temp_dir"
                    fi
                fi
            fi
        fi
        
        if [ -z "$project_dir" ] || [ ! -d "$project_dir/deploy_files/judge2/core" ]; then
            local current_dir=$(pwd)
            local search_dir="$current_dir"
            for i in {1..5}; do
                if [ -d "$search_dir/deploy_files/judge2/core" ]; then
                    project_dir="$search_dir"
                    break
                fi
                search_dir=$(cd "$search_dir/.." 2>/dev/null && pwd || echo "")
                if [ "$search_dir" = "/" ] || [ -z "$search_dir" ]; then
                    break
                fi
            done
        fi
        
        if [ -n "$project_dir" ]; then
            local judge2_core_dir="$project_dir/deploy_files/judge2/core"
            if [ -d "$judge2_core_dir" ]; then
                JUDGE_MOUNT="-v $judge2_core_dir:/core"
                echo "  ✅ 开发模式已启用：源码目录挂载"
                echo "     挂载路径: $judge2_core_dir -> /core"
                echo "     说明: 容器内的 /core 目录将映射到项目源码目录"
                echo "           修改源码后，容器内会立即生效（无需重新构建镜像）"
                echo ""
            else
                echo "  ❌ 错误: 找到项目目录 $project_dir，但不存在 $judge2_core_dir"
                echo "     开发模式挂载失败，将使用镜像内的代码"
                echo ""
            fi
        else
            echo "  ⚠️  警告: 无法找到项目源码目录（deploy_files/judge2/core）"
            echo "     开发模式挂载失败，将使用镜像内的代码"
            echo "     提示: 请确保在项目根目录或 start_scripts 目录下运行脚本"
            echo ""
        fi
    fi
    
    local judge_image=""
    local target_image="csgrandeur/ccpcoj-judge2:$CSGOJ_VERSION"
    
    local skip_pull=false
    if [ "${DOCKER_PULL_NEW:-1}" = "0" ] || [ "${NO_DOCKER_PULL:-0}" = "1" ]; then
        skip_pull=true
    fi
    
    find_local_judge_image() {
        local image_repo="csgrandeur/ccpcoj-judge2"
        local latest_image="$image_repo:latest"
        if docker image inspect "$latest_image" >/dev/null 2>&1 && \
           docker run --rm --entrypoint /bin/sh "$latest_image" -c "echo test" >/dev/null 2>&1; then
            echo "$latest_image"
            return 0
        fi
        local local_images=$(docker images --format "{{.Repository}}:{{.Tag}}" "$image_repo" 2>/dev/null | grep -v "^$" || true)
        if [ -n "$local_images" ]; then
            for img in $local_images; do
                if [ "$img" = "$latest_image" ]; then
                    continue
                fi
                if docker image inspect "$img" >/dev/null 2>&1 && \
                   docker run --rm --entrypoint /bin/sh "$img" -c "echo test" >/dev/null 2>&1; then
                    echo "$img"
                    return 0
                fi
            done
        fi
        return 1
    }
    
    echo "  尝试使用镜像: $target_image"
    if docker image inspect "$target_image" >/dev/null 2>&1 && \
       docker run --rm --entrypoint /bin/sh "$target_image" -c "echo test" >/dev/null 2>&1; then
        judge_image="$target_image"
        echo "  ✅ 使用镜像: $target_image (本地存在)"
    else
        if [ "$skip_pull" = true ]; then
            echo "  ⚠️  跳过镜像拉取（DOCKER_PULL_NEW=0 或 NO_DOCKER_PULL=1），尝试使用本地镜像"
            local found_image
            found_image=$(find_local_judge_image)
            if [ $? -eq 0 ] && [ -n "$found_image" ]; then
                judge_image="$found_image"
                if [ "$found_image" = "csgrandeur/ccpcoj-judge2:latest" ]; then
                    echo "  ✅ 使用本地 latest 镜像: $judge_image"
                else
                    echo "  ⚠️  使用本地镜像: $judge_image (fallback from $target_image)"
                fi
            else
                echo "  ❌ 无法找到有效的评测机镜像"
                echo "     请检查网络连接或手动拉取: docker pull $target_image"
                return 1
            fi
        else
            echo "  📥 正在拉取镜像: $target_image"
            echo "     请稍候，这可能需要一些时间..."
            echo ""
            if docker pull "$target_image"; then
                judge_image="$target_image"
                echo ""
                echo "  ✅ 镜像拉取成功: $target_image"
            else
                echo ""
                echo "  ⚠️  镜像 $target_image 拉取失败，尝试使用本地镜像"
                local found_image
                found_image=$(find_local_judge_image)
                if [ $? -eq 0 ] && [ -n "$found_image" ]; then
                    judge_image="$found_image"
                    if [ "$found_image" = "csgrandeur/ccpcoj-judge2:latest" ]; then
                        echo "  ✅ 使用本地 latest 镜像: $judge_image"
                    else
                        echo "  ⚠️  使用本地镜像: $judge_image (fallback from $target_image)"
                    fi
                else
                    echo "  ❌ 无法找到有效的评测机镜像"
                    echo "     请检查网络连接或手动拉取: docker pull $target_image"
                    return 1
                fi
            fi
        fi
    fi
    
    local memory_gb=$(echo "$memory" | sed 's/[^0-9]//g')
    local total_memory=$((memory_gb + 1))  # 加上 1GB SHM
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  启动 Pod: $CONTAINER_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ -n "$pod_cpuset_cpus" ]; then
        echo "  CPU: ${cpus} 核心 (绑定: $pod_cpuset_cpus)"
    else
        echo "  CPU: ${cpus} 核心 (未绑定)"
    fi
    echo "  内存: ${memory} + 1GB SHM = ${total_memory}GB 总计"
    echo "  日志目录: $log_dir_path"
    echo "  日志挂载: $log_dir_path -> /judge/logs (容器内)"
    
    local docker_run_output
    docker_run_output=$(docker run --pull=never -dit $LINK_LOCAL \
        --name "$CONTAINER_NAME" \
        --privileged \
        --security-opt seccomp=unconfined \
        --cgroupns=host \
        --pid=host \
        --cpus="$cpus" \
        $CPUSET_CONFIG \
        --memory="${memory}" \
        --shm-size=1g \
        -e CSGOJ_SERVER_BASE_URL="$CSGOJ_SERVER_BASE_URL" \
        -e CSGOJ_SERVER_USERNAME="$CSGOJ_SERVER_USERNAME" \
        -e CSGOJ_SERVER_PASSWORD="$CSGOJ_SERVER_PASSWORD" \
        -e CSGOJ_SERVER_API_PATH="/ojtool/judge2" \
        -e CSGOJ_LOG_LEVEL="${CSGOJ_LOG_LEVEL:-WARNING}" \
        -v "$PATH_DATA/var/data/judge-$OJ_NAME/data:/judge/data" \
        -v "$PATH_DATA/var/data/judge-$OJ_NAME/code:/judge/code" \
        -v "$log_dir_path:/judge/logs" \
        -v /etc/localtime:/etc/localtime:ro \
        $JUDGE_MOUNT \
        --restart=unless-stopped \
        "$judge_image" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "  ✅ $CONTAINER_NAME 启动成功"
    else
        echo "  ❌ $CONTAINER_NAME 启动失败"
        echo "     错误信息:"
        echo "$docker_run_output" | head -5
        return 1
    fi
}

run_judge_main() {
    validate_and_calculate_resources $JUDGE_POD_COUNT
    
    local cpu_offset_num
    cpu_offset_num=$(calculate_cpu_offset $JUDGE_POD_COUNT $JUDGE_DOCKER_CPUS)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  查找可用 pod 索引"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local POD_INDICES=($(find_available_pod_indices $JUDGE_POD_COUNT))
    echo "  将使用索引: ${POD_INDICES[*]}"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  启动评测机 pod"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for idx in "${POD_INDICES[@]}"; do
        start_single_pod $idx $JUDGE_DOCKER_CPUS $JUDGE_DOCKER_MEMORY $cpu_offset_num
    done
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "已启动 ${#POD_INDICES[@]} 个评测机 pod"
    echo ""
    echo "查看日志:"
    echo "  # 容器日志（标准输出）"
    echo "  docker logs -f judge-$OJ_NAME"
    if [ $JUDGE_POD_COUNT -gt 1 ]; then
        echo "  docker logs -f judge-$OJ_NAME-0"
        echo "  docker logs -f judge-$OJ_NAME-1"
    fi
    echo ""
    echo "  # 评测机日志文件（映射到宿主机）"
    echo "  # 注意：日志文件在 $PATH_DATA/var/log/judger/ 目录下，不是 /data/var/log"
    if [ $JUDGE_POD_COUNT -eq 1 ]; then
        echo "  # 日志目录: $PATH_DATA/var/log/judger/judger-$OJ_NAME/"
        echo "  ls -lh $PATH_DATA/var/log/judger/judger-$OJ_NAME/"
        echo "  tail -f $PATH_DATA/var/log/judger/judger-$OJ_NAME/JudgeHost_\$(date +%Y%m%d).log"
        echo "  tail -f $PATH_DATA/var/log/judger/judger-$OJ_NAME/tmp.log"
    else
        echo "  # 日志目录: $PATH_DATA/var/log/judger/judger-$OJ_NAME-0/ 和 $PATH_DATA/var/log/judger/judger-$OJ_NAME-1/"
        echo "  ls -lh $PATH_DATA/var/log/judger/judger-$OJ_NAME-0/"
        echo "  tail -f $PATH_DATA/var/log/judger/judger-$OJ_NAME-0/JudgeHost_\$(date +%Y%m%d).log"
        echo "  tail -f $PATH_DATA/var/log/judger/judger-$OJ_NAME-1/JudgeHost_\$(date +%Y%m%d).log"
    fi
    echo ""
    echo "  # 如果日志目录为空，检查："
    echo "  # 1. 容器是否正常运行: docker ps | grep judge-$OJ_NAME"
    echo "  # 2. 日志级别设置: docker exec judge-$OJ_NAME env | grep CSGOJ_LOG_LEVEL"
    echo "  # 3. 容器内日志目录: docker exec judge-$OJ_NAME ls -lh /judge/logs"
    echo ""
}


check_ubuntu_version() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  检查系统版本"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ ! -f /etc/os-release ]; then
        echo "❌ 错误: 无法检测系统版本（/etc/os-release 不存在）"
        echo "   此脚本仅支持 Ubuntu 系统"
        exit 1
    fi
    
    source /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        echo "❌ 错误: 此脚本仅支持 Ubuntu 系统"
        echo "   当前系统: $ID"
        exit 1
    fi
    
    echo "  检测到系统: $PRETTY_NAME"
    echo "  版本号: $VERSION_ID"
    
    local major_version
    local minor_version
    major_version=$(echo "$VERSION_ID" | cut -d. -f1)
    minor_version=$(echo "$VERSION_ID" | cut -d. -f2)
    
    if [ -z "$minor_version" ]; then
        minor_version=0
    fi
    
    if [ "$major_version" -lt 22 ] || \
       ([ "$major_version" -eq 22 ] && [ "$minor_version" -lt 4 ]); then
        echo ""
        echo "❌ 错误: Ubuntu 版本太低，不支持评测机部署"
        echo "   当前版本: Ubuntu $VERSION_ID"
        echo "   最低要求: Ubuntu 22.04 或更高版本（评测机需要）"
        echo ""
        echo "💡 建议: 请升级系统到 Ubuntu 22.04 或更高版本"
        echo ""
        exit 1
    fi
    
    echo "✅ Ubuntu 版本检查通过（${VERSION_ID} >= 22.04）"
    echo ""
}

check_cgroup_v2_enabled() {
    if grep -q "cgroup2" /proc/mounts 2>/dev/null; then
        return 0
    fi
    
    if [ -f /sys/fs/cgroup/memory.max ]; then
        return 0
    fi
    
    return 1
}

check_memory_peak_support() {
    if [ -f "/sys/fs/cgroup/memory.peak" ]; then
        if cat "/sys/fs/cgroup/memory.peak" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    local current_cgroup
    current_cgroup=$(cat /proc/self/cgroup 2>/dev/null | grep "^0::" | head -1 | cut -d: -f3)
    
    if [ -n "$current_cgroup" ] && [ "$current_cgroup" != "/" ]; then
        local memory_peak_path="/sys/fs/cgroup$current_cgroup/memory.peak"
        if [ -f "$memory_peak_path" ]; then
            if cat "$memory_peak_path" >/dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    
    if find /sys/fs/cgroup -maxdepth 2 -name "memory.peak" -readable 2>/dev/null | grep -q .; then
        return 0
    fi
    
    return 1
}

upgrade_kernel() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  升级内核"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⚠️  注意: 内核升级完成后需要重启系统才能生效"
    echo ""
    
    echo "📦 更新软件包列表..."
    sudo apt-get update
    
    echo ""
    echo "📦 安装最新内核..."
    sudo apt-get install -y linux-generic-hwe-22.04
    
    echo ""
    echo "✅ 内核升级完成"
    echo ""
    echo "⚠️  重要提示:"
    echo "   内核升级完成后，需要重启系统才能使用新内核"
    echo "   重启命令: sudo reboot"
    echo ""
    
    read -p "是否立即重启系统？(y/n, 默认: n): " reboot_now
    reboot_now=${reboot_now:-n}
    
    if [ "$reboot_now" = "y" ] || [ "$reboot_now" = "Y" ]; then
        echo ""
        echo "🔄 正在重启系统..."
        sudo reboot
    else
        echo ""
        echo "💡 请稍后手动重启系统以使用新内核:"
        echo "   sudo reboot"
        echo ""
    fi
}

check_memory_peak() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  检查系统资源监控功能"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! check_cgroup_v2_enabled; then
        echo "❌ 错误: 系统资源管理功能未启用"
        echo ""
        echo "💡 此功能是评测机部署的必要条件"
        echo "   评测机需要启用新的资源管理功能才能正常监控程序运行"
        echo ""
        echo "   启用方法（Ubuntu 22.04+）："
        echo "   1. 编辑 /etc/default/grub"
        echo "   2. 添加或修改: GRUB_CMDLINE_LINUX=\"systemd.unified_cgroup_hierarchy=1\""
        echo "   3. 执行: sudo update-grub"
        echo "   4. 重启系统"
        echo ""
        exit 1
    fi
    
    echo "✅ 系统资源管理功能已启用"
    
    local kernel_version
    kernel_version=$(uname -r)
    echo "  当前内核版本: $kernel_version"
    
    if check_memory_peak_support; then
        echo "✅ 内存监控功能正常"
        echo ""
        return 0
    fi
    
    if check_kernel_version_ge_5_19; then
        echo "❌ 内存监控功能不可用（可能是配置问题或环境限制）"
        echo ""
        echo "💡 评测机需要监控程序内存使用情况"
        echo "   当前内核: $kernel_version（版本已满足要求 >= 5.19）"
        echo ""
        
        if grep -q "microsoft" /proc/version 2>/dev/null || \
           grep -q "WSL2" <<< "$kernel_version"; then
            echo "⚠️  检测到 WSL2 环境"
            echo "   WSL2 可能不支持完整的 cgroup 功能，这是已知限制"
            echo "   建议在原生 Linux 环境中部署评测机"
            echo ""
        else
            echo "   可能的原因："
            echo "   1. cgroup 配置问题"
            echo "   2. 权限不足，无法创建测试 cgroup"
            echo "   3. 系统限制"
            echo ""
        fi
    else
        echo "❌ 系统内核版本较旧，不支持完整的内存监控功能"
        echo ""
        echo "💡 评测机需要监控程序内存使用情况，需要较新的内核版本"
        echo "   当前内核: $kernel_version"
        echo "   需要版本: 5.19 或更高（评测机需要）"
        echo ""
        echo "   可以通过升级内核来解决："
        echo "   - Ubuntu 22.04: 自动安装最新内核"
        echo ""
    fi
    
    if check_kernel_version_ge_5_19; then
        echo "⚠️  警告: 内存监控功能不可用，评测机部署可能无法正常工作"
        echo ""
        
        if [ "$NONINTERACTIVE" != "true" ]; then
            read -p "是否继续部署？(y/n, 默认: n): " continue_deploy
            continue_deploy=${continue_deploy:-n}
            
            if [ "$continue_deploy" != "y" ] && [ "$continue_deploy" != "Y" ]; then
                echo ""
                echo "❌ 部署已取消"
                exit 1
            fi
        else
            exit 1
        fi
    else
        if [ "$NONINTERACTIVE" != "true" ]; then
            read -p "是否现在升级内核？(y/n, 默认: y): " upgrade_kernel_confirm
            upgrade_kernel_confirm=${upgrade_kernel_confirm:-y}
            
            if [ "$upgrade_kernel_confirm" = "y" ] || [ "$upgrade_kernel_confirm" = "Y" ]; then
                upgrade_kernel
                echo ""
                echo "⚠️  系统检查已暂停，请重启系统后重新运行部署脚本"
                exit 0
            else
                echo ""
                echo "⚠️  警告: 未升级内核，评测机部署可能无法正常工作"
                echo "   如需升级内核，请稍后运行："
                echo "   sudo apt-get update"
                echo "   sudo apt-get install -y linux-generic-hwe-22.04"
                echo "   sudo reboot"
                echo ""
                exit 1
            fi
        else
            echo "❌ 错误: 系统内核版本较旧，无法为评测机提供完整的内存监控功能"
            echo ""
            echo "   请手动升级内核："
            echo "   sudo apt-get update"
            echo "   sudo apt-get install -y linux-generic-hwe-22.04"
            echo "   sudo reboot"
            echo ""
            exit 1
        fi
    fi
}

system_check() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  评测机系统环境检查"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    check_ubuntu_version
    
    check_memory_peak
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  系统检查完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✅ 所有检查通过，系统满足部署要求"
    echo ""
}

interactive_configure_web() {
    local skip_if_provided="$1"  # 如果为 "skip"，则跳过已提供的参数
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  OJ Web Server 配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local has_provided_params=false
    if [ "$skip_if_provided" = "skip" ]; then
        if [ -n "$PATH_DATA" ] || [ -n "$OJ_NAME" ] || [ -n "$CSGOJ_VERSION" ] || \
           [ -n "$WITH_MYSQL" ] || [ -n "$PASS_SQL_ROOT" ] || [ -n "$SQL_USER" ] || \
           [ -n "$PASS_SQL_USER" ] || [ -n "$PORT_OJ" ] || [ -n "$PORT_MYADMIN" ]; then
            has_provided_params=true
            echo ""
            echo "✅ 已提供的参数（将跳过询问）:"
            if [ -n "$PATH_DATA" ]; then
                echo "   - 数据目录: $PATH_DATA"
            fi
            if [ -n "$OJ_NAME" ]; then
                echo "   - OJ 名称: $OJ_NAME"
            fi
            if [ -n "$CSGOJ_VERSION" ]; then
                echo "   - Docker 镜像版本: $CSGOJ_VERSION"
            fi
            if [ -n "$WITH_MYSQL" ]; then
                echo "   - 部署 MySQL 容器: $([ "$WITH_MYSQL" = "1" ] && echo "是" || echo "否")"
            fi
            if [ -n "$SQL_HOST" ] && [ "$SQL_HOST" != "db" ]; then
                echo "   - MySQL 主机: $SQL_HOST"
            fi
            if [ -n "$PORT_OJ" ]; then
                echo "   - OJ Web 端口: $PORT_OJ"
            fi
            if [ -n "$PORT_MYADMIN" ]; then
                echo "   - PHPMyAdmin 端口: $PORT_MYADMIN"
            fi
            echo ""
        fi
    fi
    
    if [ "$has_provided_params" = true ]; then
        echo "⚠️  以下参数仍需配置:"
    else
        echo ""
        echo "💡 以下为所有配置参数，直接回车使用当前值（配置文件或默认值）"
    fi
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  基础配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ -z "$PATH_DATA" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "数据目录 (当前: ${PATH_DATA}): " input_path_data
        PATH_DATA="${input_path_data:-$PATH_DATA}"
    fi
    
    if [ -z "$OJ_NAME" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "OJ 名称 (当前: ${OJ_NAME}): " input_oj_name
        OJ_NAME="${input_oj_name:-$OJ_NAME}"
    fi
    
    if [ -z "$CSGOJ_VERSION" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "Docker 镜像版本 (当前: ${CSGOJ_VERSION}): " input_version
        CSGOJ_VERSION="${input_version:-$CSGOJ_VERSION}"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MySQL 配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ -z "$WITH_MYSQL" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "部署 MySQL 容器？(y/n, 当前: $([ "$WITH_MYSQL" = "1" ] && echo "y" || echo "n")): " input_with_mysql
        if [ -z "$input_with_mysql" ]; then
            :
        elif [ "$input_with_mysql" = "y" ] || [ "$input_with_mysql" = "Y" ]; then
            WITH_MYSQL=1
        else
            WITH_MYSQL=0
        fi
    fi
    
    if [ "$WITH_MYSQL" = "1" ]; then
        echo "💡 本地 MySQL 容器配置"
        echo ""
        
        if [ -z "$PASS_SQL_ROOT" ] || [ "$skip_if_provided" != "skip" ]; then
            read -p "MySQL Root 密码 (当前: ${PASS_SQL_ROOT}): " input_pass_sql_root
            PASS_SQL_ROOT="${input_pass_sql_root:-$PASS_SQL_ROOT}"
        fi
        
        SQL_USER="${SQL_USER:-csgcpc}"
        
        if [ -z "$PASS_SQL_USER" ] || [ "$skip_if_provided" != "skip" ]; then
            read -p "MySQL 业务用户密码 (当前: ${PASS_SQL_USER}): " input_pass_sql_user
            PASS_SQL_USER="${input_pass_sql_user:-$PASS_SQL_USER}"
        fi
        
        SQL_HOST="db"
        
        if [ -z "$PORT_DB" ] || [ "$skip_if_provided" != "skip" ]; then
            read -p "MySQL 外部映射端口 (当前: ${PORT_DB:-20006}): " input_port_db
            PORT_DB="${input_port_db:-${PORT_DB:-20006}}"
        fi
        
        if [ -z "$PORT_OJ_DB" ] || [ "$skip_if_provided" != "skip" ]; then
            read -p "OJ Web 连接 MySQL 端口 (当前: ${PORT_OJ_DB:-3306}): " input_port_oj_db
            PORT_OJ_DB="${input_port_oj_db:-${PORT_OJ_DB:-3306}}"
        fi
    else
        echo "💡 外连 MySQL 配置"
        echo ""
        
        if [ -z "$SQL_HOST" ] || [ "$SQL_HOST" = "db" ] || [ "$skip_if_provided" != "skip" ]; then
            echo "⚠️  需要提供外部 MySQL 服务器的连接信息"
            echo ""
            
            while true; do
                read -p "MySQL 服务器地址（IP 或域名，必填）: " input_sql_host
                if [ -n "$input_sql_host" ]; then
                    SQL_HOST="$input_sql_host"
                    break
                fi
                echo "❌ MySQL 服务器地址不能为空，请重新输入"
            done
            echo ""
        fi
        
        if [ -z "$SQL_USER" ] || [ "$skip_if_provided" != "skip" ]; then
            read -p "MySQL 业务用户 (当前: ${SQL_USER}): " input_sql_user
            SQL_USER="${input_sql_user:-$SQL_USER}"
        fi
        
        if [ -z "$PASS_SQL_USER" ] || [ "$skip_if_provided" != "skip" ]; then
            read -sp "MySQL 业务用户密码 (必填): " input_pass_sql_user
            echo ""
            while [ -z "$input_pass_sql_user" ]; do
                echo "❌ MySQL 业务用户密码不能为空"
                read -sp "MySQL 业务用户密码 (必填): " input_pass_sql_user
                echo ""
            done
            PASS_SQL_USER="$input_pass_sql_user"
        fi
        
        PORT_DB=""
        
        if [ -z "$PORT_OJ_DB" ] || [ "$skip_if_provided" != "skip" ]; then
            read -p "OJ Web 连接 MySQL 端口 (当前: ${PORT_OJ_DB:-3306}): " input_port_oj_db
            PORT_OJ_DB="${input_port_oj_db:-${PORT_OJ_DB:-3306}}"
        fi
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  OJ Web 配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ -z "$PORT_OJ" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "OJ Web 端口 (当前: ${PORT_OJ}): " input_port_oj
        PORT_OJ="${input_port_oj:-$PORT_OJ}"
    fi
    
    if [ -z "$PORT_MYADMIN" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "PHPMyAdmin 端口 (当前: ${PORT_MYADMIN}): " input_port_myadmin
        PORT_MYADMIN="${input_port_myadmin:-$PORT_MYADMIN}"
    fi
    
    if [ -z "$PASS_MYADMIN_PAGE" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "PHPMyAdmin 页面访问密码 (当前: ${PASS_MYADMIN_PAGE}): " input_pass_myadmin
        PASS_MYADMIN_PAGE="${input_pass_myadmin:-$PASS_MYADMIN_PAGE}"
    fi
    
    OJ_CDN="${OJ_CDN:-local}"
    
    OJ_MODE="${OJ_MODE:-cpcsys}"
    
    OJ_STATUS="${OJ_STATUS:-cpc}"
    
    SECRET_KEY="${SECRET_KEY:-super_secret_oj}"
    
    NGINX_PORT_RANGES="${NGINX_PORT_RANGES:-}"
    
    if [ "$PROVIDED_BELONG_TO" != "true" ]; then
        BELONG_TO="$OJ_NAME"
    fi
    
    echo ""
}

interactive_configure_judge() {
    local skip_if_provided="$1"  # 如果为 "skip"，则跳过已提供的参数
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  评测机节点配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local has_provided_params=false
    if [ "$skip_if_provided" = "skip" ]; then
        if [ -n "$CSGOJ_SERVER_BASE_URL" ] || [ -n "$CSGOJ_SERVER_USERNAME" ] || \
           [ -n "$CSGOJ_SERVER_PASSWORD" ]; then
            has_provided_params=true
            echo ""
            echo "✅ 已提供的参数（将跳过询问）:"
            if [ -n "$CSGOJ_SERVER_BASE_URL" ]; then
                echo "   - OJ Web 服务器地址: $CSGOJ_SERVER_BASE_URL"
            fi
            if [ -n "$CSGOJ_SERVER_USERNAME" ]; then
                echo "   - 评测机用户名: $CSGOJ_SERVER_USERNAME"
            fi
            if [ -n "$CSGOJ_SERVER_PASSWORD" ]; then
                echo "   - 评测机密码: [已提供]"
            fi
            echo ""
        fi
    fi
    
    if [ "$has_provided_params" = true ]; then
        echo "⚠️  以下参数仍需填写:"
    else
        echo "⚠️  注意：请使用评测机容器能访问到的 OJ Web 服务器地址"
        echo "   不要使用 localhost 或 127.0.0.1（评测机容器内无法访问宿主机 localhost）"
        echo "   如果评测机和 Web 在同一台机器，使用服务器的内网或外网 IP"
    fi
    echo ""
    
    if [ -z "$CSGOJ_SERVER_BASE_URL" ] || [ "$skip_if_provided" != "skip" ]; then
        while true; do
            read -p "OJ Web 服务器地址 (必需，例如: http://192.168.1.100:20080): " input_base_url
            if [ -n "$input_base_url" ]; then
                CSGOJ_SERVER_BASE_URL="$input_base_url"
                break
            fi
            echo "❌ 错误: 服务器地址不能为空，请重新输入"
        done
        echo ""
    fi
    
    if [ -z "$CSGOJ_SERVER_USERNAME" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "评测机用户名 (默认: judger): " input_username
        CSGOJ_SERVER_USERNAME="${input_username:-judger}"
        echo ""
    fi
    
    if [ -z "$CSGOJ_SERVER_PASSWORD" ] || [ "$skip_if_provided" != "skip" ]; then
        while true; do
            read -sp "评测机密码 (必需): " input_password
            echo ""
            if [ -n "$input_password" ]; then
                CSGOJ_SERVER_PASSWORD="$input_password"
                break
            fi
            echo "❌ 错误: 密码不能为空，请重新输入"
        done
        echo ""
    fi
    
    if [ -z "$PATH_DATA" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "数据目录 (默认: $PATH_DATA): " input_path_data
        PATH_DATA="${input_path_data:-$PATH_DATA}"
        echo ""
    fi
    
    if [ -z "$JUDGE_POD_COUNT" ] || [ "$JUDGE_POD_COUNT" = "1" ] || [ "$skip_if_provided" != "skip" ]; then
        read -p "启动 pod 数量 (默认: 1): " input_pod_count
        JUDGE_POD_COUNT="${input_pod_count:-1}"
        echo ""
    fi
    
    echo "💡 资源将自动分配（CPU 和内存会根据系统资源智能计算）"
    echo ""
}


interactive_configure() {
    local selected_mode
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  CSGOJ 部署内容选择"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "请选择部署内容："
    echo "  web   - OJ Web Server（Web 服务器，包含 MySQL、Nginx、PHP 等服务）"
    echo "  judge - Judge Node（评测机节点，仅启动评测服务）"
    echo ""
    read -p "请输入选项 (web/judge, 默认: web): " selected_mode
    selected_mode=${selected_mode:-web}
    selected_mode=$(echo "$selected_mode" | tr '[:upper:]' '[:lower:]')
    
    if [ "$selected_mode" != "web" ] && [ "$selected_mode" != "judge" ]; then
        echo "❌ 无效选项，请输入 'web' 或 'judge'"
        exit 1
    fi
    
    INTERACTIVE_SELECTED_MODE="$selected_mode"
    
    if [ "$selected_mode" = "judge" ]; then
        interactive_configure_judge ""
        
        deploy_judge "$CSGOJ_SERVER_BASE_URL" "$CSGOJ_SERVER_USERNAME" "$CSGOJ_SERVER_PASSWORD" "$JUDGE_POD_COUNT" ""
        exit $?
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  OJ Web Server 部署"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "💡 将使用默认配置部署 Web 服务"
        echo "   如需自定义配置，请使用参数或配置文件"
        echo ""
        return 0
    fi
}



interactive_complete_judge_params() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  缺少必要参数，进入交互式配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    interactive_configure_judge "skip"
}

interactive_configure_web_first_time() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  OJ Web Server 首次部署配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    interactive_configure_web ""
}

display_config_info() {
    local config_file_path="$1"
    local deploy_mode="$2"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  配置文件已保存"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📁 配置文件路径: $config_file_path"
    echo ""
    echo "💡 下次运行说明："
    echo "   • 如果不提供参数，将自动使用此配置文件中的配置"
    echo "   • 使用方式: bash csgoj_deploy.sh"
    if [ "$deploy_mode" = "judge" ]; then
        echo "   • 或指定模式: bash csgoj_deploy.sh judge"
    fi
    echo ""
    echo "📋 当前配置摘要："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "$deploy_mode" = "judge" ]; then
        echo "  部署内容: Judge Node"
        echo "  服务器地址: $CSGOJ_SERVER_BASE_URL"
        echo "  用户名: $CSGOJ_SERVER_USERNAME"
        echo "  Pod 数量: $JUDGE_POD_COUNT"
    else
        echo "  部署内容: OJ Web Server"
        echo "  OJ 名称: $OJ_NAME"
        echo "  数据目录: $PATH_DATA"
        echo "  Web 端口: $PORT_OJ"
        echo "  数据库端口: $PORT_DB"
        if [ "$WITH_MYSQL" = "1" ]; then
            echo "  MySQL: 容器部署"
        else
            echo "  MySQL: 外部连接 ($SQL_HOST)"
        fi
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}



main() {
    local DEPLOY_MODE=''
    local REMAINING_ARGS=()
    
    local DEFAULT_CONFIG="${DEFAULT_CONFIG:-./data/csgoj_config.cfg}"
    
    if [ $# -gt 0 ]; then
        case "$1" in
            web|judge)
                DEPLOY_MODE="$1"
                shift
                REMAINING_ARGS=("$@")
                ;;
            --help|-h|-H)
                show_help
                exit 0
                ;;
            *)
                for arg in "$@"; do
                    if [[ "$arg" == *"CSGOJ_SERVER_BASE_URL"* ]] || [[ "$arg" == *"CSGOJ_SERVER_PASSWORD"* ]]; then
                        DEPLOY_MODE="judge"
                        break
                    fi
                done
                if [ -z "$DEPLOY_MODE" ]; then
                    INTERACTIVE_SELECTED_MODE=""
                    interactive_configure
                    if [ "$INTERACTIVE_SELECTED_MODE" = "web" ]; then
                        DEPLOY_MODE="web"
                    elif [ -z "$INTERACTIVE_SELECTED_MODE" ]; then
                        DEPLOY_MODE="web"
                    fi
                fi
                REMAINING_ARGS=("$@")
                ;;
        esac
    else
        INTERACTIVE_SELECTED_MODE=""
        interactive_configure
        if [ "$INTERACTIVE_SELECTED_MODE" = "web" ]; then
            DEPLOY_MODE="web"
        elif [ -z "$INTERACTIVE_SELECTED_MODE" ]; then
            DEPLOY_MODE="web"
        fi
    fi
    
    if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
        parse_args "${REMAINING_ARGS[@]}"
    else
        parse_args
    fi
    
    local JUDGE_NODE_MODE=false
    if [ "$DEPLOY_MODE" = "judge" ]; then
        JUDGE_NODE_MODE=true
    elif [ "$DEPLOY_MODE" = "web" ]; then
        JUDGE_NODE_MODE=false
    elif [ -z "$DEPLOY_MODE" ]; then
        for arg in "${REMAINING_ARGS[@]}"; do
            if [[ "$arg" == *"CSGOJ_SERVER_BASE_URL"* ]] || [[ "$arg" == *"CSGOJ_SERVER_PASSWORD"* ]]; then
                JUDGE_NODE_MODE=true
                break
            fi
        done
        if [ "$JUDGE_NODE_MODE" = false ]; then
            DEPLOY_MODE="web"
            JUDGE_NODE_MODE=false
        fi
    else
        DEPLOY_MODE="web"
        JUDGE_NODE_MODE=false
    fi
    
    if [ "$JUDGE_NODE_MODE" = true ]; then
        deploy_judge "${REMAINING_ARGS[@]}"
        exit $?
    fi
    
    deploy_web
}


deploy_judge() {
    
    local is_interactive_mode=false
    if [ $# -ge 3 ] && [[ ! "$1" == --* ]] && [[ "$1" != *"="* ]]; then
        is_interactive_mode=true
        CSGOJ_SERVER_BASE_URL="$1"
        CSGOJ_SERVER_USERNAME="$2"
        CSGOJ_SERVER_PASSWORD="$3"
        JUDGE_POD_COUNT="${4:-1}"
        RESTART_ALL="${5:-false}"
    fi
    
    if [ "$RESTART_ALL" = false ] && [ "$REBUILD_ALL" = false ] && [ "$REMOVE_ALL" = false ]; then
        local missing_params=false
        if [ -z "$CSGOJ_SERVER_BASE_URL" ] || [ -z "$CSGOJ_SERVER_USERNAME" ] || [ -z "$CSGOJ_SERVER_PASSWORD" ]; then
            missing_params=true
        fi
        
        if [ "$missing_params" = true ]; then
            if [ "$NONINTERACTIVE" = true ]; then
                echo "❌ 错误: 必须提供 CSGOJ_SERVER_BASE_URL、CSGOJ_SERVER_USERNAME 和 CSGOJ_SERVER_PASSWORD" >&2
                echo ""
                echo "使用方式："
                echo "  bash csgoj_deploy.sh judge --CSGOJ_SERVER_BASE_URL=... --CSGOJ_SERVER_USERNAME=... --CSGOJ_SERVER_PASSWORD=..."
                echo ""
                echo "或使用交互式（不使用 --noninteractive）："
                echo "  bash csgoj_deploy.sh"
                echo ""
                exit 1
            else
                interactive_complete_judge_params
            fi
        fi
    elif [ "$REBUILD_ALL" = true ]; then
        if [ -z "$CSGOJ_SERVER_BASE_URL" ] || [ -z "$CSGOJ_SERVER_USERNAME" ] || [ -z "$CSGOJ_SERVER_PASSWORD" ]; then
            if [ "$NONINTERACTIVE" = true ]; then
                echo "❌ 错误: 重开模式（--rebuild-all）需要提供启动参数：CSGOJ_SERVER_BASE_URL、CSGOJ_SERVER_USERNAME 和 CSGOJ_SERVER_PASSWORD" >&2
                echo ""
                echo "使用方式："
                echo "  bash csgoj_deploy.sh judge --CSGOJ_SERVER_BASE_URL=... --CSGOJ_SERVER_USERNAME=... --CSGOJ_SERVER_PASSWORD=... --rebuild-all"
                echo ""
                exit 1
            else
                interactive_complete_judge_params
            fi
        fi
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Judge Node 部署"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  OJ 名称: $OJ_NAME"
    if [ "$RESTART_ALL" = false ]; then
        echo "  服务器地址: $CSGOJ_SERVER_BASE_URL"
        echo "  用户名: $CSGOJ_SERVER_USERNAME"
    fi
    echo ""
    
    if [ "$RESTART_ALL" = false ] && [ "$REMOVE_ALL" = false ]; then
        system_check
    fi
    
    install_docker
    
    if [ -z "$(docker network ls | grep $DOCKER_NET_NAME)" ]; then
        docker network create $DOCKER_NET_NAME >/dev/null 2>&1
    fi
    
    if [ "$RESTART_ALL" = true ]; then
        restart_all_judge_pods
        exit 0
    fi
    
    if [ "$REMOVE_ALL" = true ]; then
        remove_all_judge_pods
        exit 0
    fi
    
    if [ "$REBUILD_ALL" = true ]; then
        rebuild_all_judge_pods
    fi
    
    run_judge_main
    
    local config_file_path
    config_file_path=$(write_full_config_file "$DEFAULT_CONFIG" "judge")
    display_config_info "$config_file_path" "judge"
}

deploy_web() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  CSGOJ OJ Web Server 部署"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    
    DEFAULT_CONFIG="${DEFAULT_CONFIG:-./data/csgoj_config.cfg}"
    
    local config_exists=false
    if [ "$IGNORE_CONFIG" != true ] && [ -f "$DEFAULT_CONFIG" ]; then
        config_exists=true
    fi
    
    if [ "$config_exists" = false ] && [ "$NONINTERACTIVE" != true ]; then
        interactive_configure_web_first_time
    fi
    
    install_docker
    
    if [ -z "$(docker network ls | grep "$DOCKER_NET_NAME")" ]; then
        docker network create "$DOCKER_NET_NAME" >/dev/null 2>&1
    fi
    
    start_db          # 内部检查 WITH_MYSQL 和容器是否存在
    start_myadmin     # 内部检查容器是否存在
    start_ojweb       # 内部检查容器是否存在
    start_nginx       # 内部检查容器是否存在
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  部署完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "容器已启动，初始化需要一定时间，可用以下命令查看启动状态："
    echo "  docker logs php-$OJ_NAME"
    echo "  docker logs nginx-server"
    if [ "$WITH_MYSQL" = "1" ]; then
        echo "  docker logs db"
    fi
    echo ""
    echo "💡 首次访问 Web 页面时，系统将引导您设置管理员账号和评测机账号"
    echo ""
    
    local config_file_path
    config_file_path=$(write_full_config_file "$DEFAULT_CONFIG" "web")
    display_config_info "$config_file_path" "web"
    
    echo "💡 评测机部署："
    echo "   评测机需要在 Web 管理界面设置 judger 账号后，使用以下命令启动："
    echo ""
    echo "   bash csgoj_deploy.sh judge \\"
    echo "       --CSGOJ_SERVER_BASE_URL=http://<OJ服务器IP或域名>:${PORT_OJ} \\"
    echo "       --CSGOJ_SERVER_USERNAME=<评测机分配的账号> \\"
    echo "       --CSGOJ_SERVER_PASSWORD=<在Web界面设置的密码>"
    echo ""
    echo "   或使用交互式："
    echo "   bash csgoj_deploy.sh"
    echo ""
    echo "   ⚠️  注意：不要使用 localhost 或 127.0.0.1"
    echo ""
}

main "$@"

#!/bin/bash

# 设置严格模式
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的环境变量
check_env() {
    if [ ! -f .env ]; then
        log_error ".env 文件不存在"
        exit 1
    fi

    source .env
    local required_vars=("DERP_DOMAIN" "DERP_PORT" "DERP_STUN_PORT" "HEADSCALE_PORT")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "$var 环境变量未设置"
            exit 1
        fi
    done
}

# 安装单个工具
install_tool() {
    local tool_name=$1
    local package_managers=("apt" "yum" "dnf" "pacman" "zypper")

    for pm in "${package_managers[@]}"; do
        if command -v $pm &>/dev/null; then
            case $pm in
            "pacman")
                sudo $pm -S --noconfirm $tool_name
                ;;
            *)
                sudo $pm install -y $tool_name
                ;;
            esac
            return 0
        fi
    done
    return 1
}

# 检查并安装必要工具
check_utils() {
    local tools=("openssl" "yq" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &>/dev/null; then
            log_warn "未找到 $tool 命令"
            read -p "是否自动安装?(y/n) " choice
            if [ "${choice,,}" = "y" ]; then
                if ! install_tool $tool; then
                    log_error "无法自动安装 $tool，请手动安装"
                    exit 1
                fi
                log_info "$tool 安装成功"
            else
                log_error "请先安装 $tool 后再运行"
                exit 1
            fi
        fi
    done
}

# 生成证书
gen_cert() {
    check_env
    local cert_dir="certs"
    local cert_file="${cert_dir}/${DERP_DOMAIN}.crt"
    local key_file="${cert_dir}/${DERP_DOMAIN}.key"

    if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
        log_info "证书文件已存在,跳过证书生成"
        return
    fi

    mkdir -p $cert_dir
    cd $cert_dir

    if [[ $DERP_DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local alt_name="IP:${DERP_DOMAIN}"
    else
        local alt_name="DNS:${DERP_DOMAIN}"
    fi

    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout ${DERP_DOMAIN}.key -out ${DERP_DOMAIN}.crt -subj "/CN=${DERP_DOMAIN}" -addext "subjectAltName=${alt_name}"

    cd ..
    log_info "为 ${DERP_DOMAIN} 生成证书成功"
}

# 生成配置文件
gen_config() {
    check_env

    log_info "配置信息:"
    log_info "域名/IP: ${DERP_DOMAIN}"
    log_info "DERP端口: ${DERP_PORT}"
    log_info "STUN端口: ${DERP_STUN_PORT}"
    log_info "Headscale端口: ${HEADSCALE_PORT}"
    log_info "DERP文件端口: ${DERP_FILE_PORT}"

    read -p "是否继续? (y/n) " choice
    if [ "${choice,,}" != "y" ]; then
        log_info "退出..."
        exit 0
    fi

    log_info "生成配置文件..."

    # Headscale配置
    cp headscale/config/config-example.yaml headscale/config/config.yaml
    yq eval ".server_url = \"http://${DERP_DOMAIN}:${HEADSCALE_PORT}\"" -i headscale/config/config.yaml
    yq eval ".listen_addr = \"0.0.0.0:${HEADSCALE_PORT}\"" -i headscale/config/config.yaml
    yq eval ".randomize_client_port = true" -i headscale/config/config.yaml
    yq eval ".derp.urls += [\"http://${DERP_DOMAIN}:8480/derp.json\"]" -i headscale/config/config.yaml

    # Headplane配置
    cp headplane/config/config-example.yaml headplane/config/config.yaml
    local cookie_secret=$(openssl rand -base64 32 | tr -d '/+' | cut -c1-32)
    yq eval ".server.cookie_secret = \"${cookie_secret}\"" -i headplane/config/config.yaml
    yq eval ".headscale.url = \"http://headscale:${HEADSCALE_PORT}\"" -i headplane/config/config.yaml
    yq eval ".integration.docker.enabled = true" -i headplane/config/config.yaml
    yq eval ".server.cookie_secure = false" -i headplane/config/config.yaml


    log_info "配置文件生成成功"
}

gen_derp_config() {
    source .env
    cp static-file/derp-example.json static-file/derp.json
    jq --arg name "$DERP_DOMAIN" '.Regions."901".Nodes[0].Name = $name' static-file/derp.json >temp.json && mv temp.json static-file/derp.json
    jq --argjson port "$DERP_PORT" '.Regions."901".Nodes[0].DERPPort = $port' static-file/derp.json >temp.json && mv temp.json static-file/derp.json
    jq --arg hostname "$DERP_DOMAIN" '.Regions."901".Nodes[0].HostName = $hostname' static-file/derp.json >temp.json && mv temp.json static-file/derp.json
    jq '.Regions."901".Nodes[0].InsecureForTests = true' static-file/derp.json >temp.json && mv temp.json static-file/derp.json
    jq --argjson port "$DERP_STUN_PORT" '.Regions."901".Nodes[0].STUNPort = $port' static-file/derp.json >temp.json && mv temp.json static-file/derp.json
    log_info "DERP配置文件生成成功"
}

# 部署服务
deploy() {
    check_env

    # 检查证书
    if [ ! -f "certs/${DERP_DOMAIN}.crt" ] || [ ! -f "certs/${DERP_DOMAIN}.key" ]; then
        log_warn "证书文件不存在,自动获取证书"
        gen_cert
    fi

    read -p "是否全新部署? (y/n) " choice
    if [ "${choice,,}" = "y" ]; then
        log_info "清空数据目录..."
        rm -rf headscale/data/*
        log_info "数据目录已清空"
    fi

    if ! gen_config; then
        log_error "生成配置文件失败"
        exit 1
    fi

    if ! gen_derp_config; then
        log_error "生成DERP配置文件失败"
        exit 1
    fi

    log_info "启动容器..."
    restart

    log_info "检查服务状态..."
    sleep 5
    if docker compose ps | grep -q "Restarting"; then
        log_error "存在服务正在重启,请检查服务日志"
        docker compose ps
        exit 1
    fi
    log_info "所有服务运行正常"

    log_info "启动成功"
    log_info "Headscale地址: http://${DERP_DOMAIN}:${HEADSCALE_PORT}/windows"
    log_info "DERP 地址: https://${DERP_DOMAIN}:${DERP_PORT}"

    log_info "请确保以下端口已放行:
    - ${HEADSCALE_PORT}/tcp: Headscale Web界面
    - ${DERP_PORT}/tcp: DERP服务
    - ${DERP_STUN_PORT}/udp: DERP STUN服务
    - ${DERP_FILE_PORT}/tcp: DERP文件服务"
}

# 重启服务
restart() {
    if ! docker compose down; then
        log_error "停止服务失败"
        exit 1
    fi

    if ! docker compose up -d; then
        log_error "启动服务失败"
        exit 1
    fi
    log_info "重启成功"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  deploy    部署服务"
    echo "  restart   重启服务"
    echo "  help      显示此帮助信息"
}

show_info() {
    source .env
    log_info "Headscale地址: http://${DERP_DOMAIN}:${HEADSCALE_PORT}/windows"
    log_info "DERP 地址: https://${DERP_DOMAIN}:${DERP_PORT}"
}

# 主菜单
menu() {
    echo "请选择操作:"
    echo "1. 部署"
    echo "2. 重启"
    echo "3. 显示信息"
    echo "4. 退出"
    read -p "请输入选项: " choice
    case $choice in
    1) deploy ;;
    2) restart ;;
    3) show_info ;;
    4) exit 0 ;;
    *) log_error "无效选项" ;;
    esac
}

# 主程序
main() {
    if [ $# -gt 0 ]; then
        case "$1" in
        "deploy") deploy ;;
        "restart") restart ;;
        "info") show_info ;;
        "help") show_help ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
        esac
    else
        check_utils
        menu
    fi
}

main "$@"

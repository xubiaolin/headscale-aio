#!/bin/bash

function check_utils(){
    # 检查 openssl 命令是否存在
    if ! command -v openssl &> /dev/null; then
        read -p "未找到 openssl 命令,是否自动安装?(y/n) " choice
        if [ "$choice" = "y" ]; then
            if command -v apt &> /dev/null; then
                sudo apt install -y openssl
            elif command -v yum &> /dev/null; then
                sudo yum install -y openssl
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y openssl
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm openssl
            elif command -v zypper &> /dev/null; then
                sudo zypper install -y openssl
            else
                echo "无法自动安装,请手动安装 openssl"
                exit 1
            fi
        else
            echo "请先安装 openssl 后再运行"
            exit 1
        fi
    fi

    # 检查 yq 命令是否存在
    if ! command -v yq &> /dev/null; then
        read -p "未找到 yq 命令,是否自动安装?(y/n) " choice
        if [ "$choice" = "y" ]; then
            if command -v apt &> /dev/null; then
                sudo apt install -y yq
            elif command -v yum &> /dev/null; then
                sudo yum install -y yq
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y yq
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm yq
            elif command -v zypper &> /dev/null; then
                sudo zypper install -y yq
            else
                echo "无法自动安装,请手动安装 yq"
                exit 1
            fi
        else
            echo "请先安装 yq 后再运行"
            exit 1
        fi
    fi
}

function gen_cert() {
    source .env
    if [ -z "$DERP_DOMAIN" ]; then
        echo "错误: DERP_DOMAIN 环境变量未设置"
        exit 1
    fi
    
    mkdir -p certs
    cd certs
    
    openssl req -x509 -newkey rsa:4096 -sha256 -days 36500 -nodes -keyout ${DERP_DOMAIN}.key -out ${DERP_DOMAIN}.crt -subj "/CN=${DERP_DOMAIN}" -addext "subjectAltName=IP:${DERP_DOMAIN}"
    cd ..
    echo "为 ${DERP_DOMAIN} 生成证书成功"
}

function gen_config(){
    source .env
    
    echo "域名/IP 为: ${DERP_DOMAIN}"
    echo "DERP端口为: ${DERP_PORT}"
    echo "STUN 端口为: ${DERP_STUN_PORT}"
    echo "Headscale 端口为: ${HEADSCALE_PORT}"
    echo "DERP_VERIFY_CLIENT_URL 为: ${DERP_VERIFY_CLIENT_URL}"

    echo "是否继续? (y/n)"
    read -p "请输入选项: " choice
    if [ "$choice" = "y" ]; then
        echo "继续..."
    else
        echo "退出..."
        exit 0
    fi

    echo "生成配置文件..."

    cp headscale-config/config-example.yaml headscale-config/config.yaml

    yq -i -y '.server_url = "'http://${DERP_DOMAIN}:${HEADSCALE_PORT}'"' headscale-config/config.yaml
    yq -i -y '.listen_addr = "'0.0.0.0:${HEADSCALE_PORT}'"' headscale-config/config.yaml
    yq -i -y '.randomize_client_port = true' headscale-config/config.yaml

    cp headplane-config/config-example.yaml headplane-config/config.yaml

    COOKIE_SECRET=$(openssl rand -base64 32 | tr -d '/+' | cut -c1-32)
    yq -i -y '.server.cookie_secret = "'${COOKIE_SECRET}'"' headplane-config/config.yaml
    yq -i -y '.headscale.url = "'http://headscale:${HEADSCALE_PORT}'"' headplane-config/config.yaml
    yq -i -y '.integration.docker.enabled = true' headplane-config/config.yaml

    echo "配置文件生成成功"
}

function start(){
    source .env

    crt=certs/${DERP_DOMAIN}.crt
    key=certs/${DERP_DOMAIN}.key

    if [ ! -f "$crt" ] || [ ! -f "$key" ]; then
        echo "警告: 证书文件不存在,自动获取证书"
        gen_cert
    fi

    gen_config
    if [ $? -ne 0 ]; then
        echo "生成配置文件失败"
        exit 1
    fi

    echo "启动 容器"
    docker compose up -d
    if [ $? -ne 0 ]; then
        echo "启动失败"
        exit 1
    fi

    echo "启动成功"
    echo "Headscale地址: https://${DERP_DOMAIN}:${HEADSCALE_PORT}"
    echo "DERP 地址: https://${DERP_DOMAIN}:${DERP_PORT}"
}


check_utils
start

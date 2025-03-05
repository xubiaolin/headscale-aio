#!/bin/bash


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

function menu() {
    echo "1. 生成证书"
    echo "0. 退出"
    read -p "请输入选项: " choice
    case $choice in
        1)
            gen_cert
        ;;
        0)
            exit 0
        ;;
        *)
            echo "无效选项"
        ;;
    esac
}

menu

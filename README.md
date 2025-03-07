# Headscale All-in-One 部署方案

这是一个用于快速部署 Headscale 和 DERP 服务的一体化解决方案。本项目集成了 Headscale 控制服务器、DERP 中继服务器以及 Web 管理界面，让您能够轻松搭建和管理自己的 Tailscale 网络。

## 功能特性

- 🚀 一键部署 Headscale 和 DERP 服务
- 🔒 自动生成和配置 SSL 证书
- 🛠 支持多种 Linux 发行版
- 📊 集成 Web 管理界面
- 🔄 支持 Docker Compose 部署
- ⚙️ 灵活的配置选项

## 系统要求

- Linux 操作系统
- Docker 和 Docker Compose
- 以下工具：
  - openssl
  - yq
  - jq

## 快速开始

1. 克隆仓库：
   ```bash
   git clone <repository_url>
   cd headscale-aio
   ```

2. 配置环境变量：
   ```bash
   cp .env.example .env
   ```
   编辑 `.env` 文件，设置以下必要参数：
   - `DERP_DOMAIN`：您的域名或IP地址
   - `DERP_PORT`：DERP 服务端口
   - `DERP_STUN_PORT`：STUN 服务端口
   - `HEADSCALE_PORT`：Headscale Web界面端口

3. 运行部署脚本：
   ```bash
   ./start.sh deploy
   ```

## 使用说明

### 命令行选项

```bash
./start.sh [选项]

选项：
  deploy    部署服务
  restart   重启服务
  info      显示服务信息
  help      显示帮助信息
```

### 交互式菜单

直接运行 `./start.sh` 将显示交互式菜单，您可以选择：
1. 部署
2. 重启
3. 显示信息
4. 退出

### 端口说明

请确保以下端口在防火墙中已开放：
- Headscale Web界面端口（默认：8080）
- DERP 服务端口（默认：443）
- DERP STUN 服务端口（默认：3478/udp）

## 配置文件

- `headscale-config/config.yaml`：Headscale 服务配置
- `headplane-config/config.yaml`：Web界面配置
- `static-file/derp.json`：DERP 服务配置

## 目录结构

```
.
├── certs/                 # SSL证书目录
├── headscale-config/      # Headscale配置文件
├── headplane-config/      # Web界面配置文件
├── headscale-data/       # Headscale数据目录
├── static-file/          # 静态文件目录
├── .env                  # 环境变量配置
├── docker-compose.yml    # Docker编排文件
└── start.sh             # 部署脚本
```

## 常见问题

1. **证书生成失败**
   - 检查 `DERP_DOMAIN` 配置是否正确
   - 确保 openssl 已正确安装

2. **服务无法启动**
   - 检查端口是否被占用
   - 查看 Docker 日志排查问题

3. **客户端无法连接**
   - 确认防火墙端口已开放
   - 检查 DERP 配置是否正确

## 维护与支持

如遇到问题，请：
1. 检查 Docker 容器日志
2. 确认配置文件正确性
3. 查看防火墙设置

## 许可证

[添加您的许可证信息] 
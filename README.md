# BangNiCMS · 部署文件公开仓库

[![Release](https://img.shields.io/github/v/release/miaochi998/bncms-deploy)](https://github.com/miaochi998/bncms-deploy/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

本仓库存放 **BangNiCMS** 的**部署相关公开文件**：一键安装脚本、Portainer 应用模板、Docker Compose 配置等。

> **业务源代码**位于私有仓库 `miaochi998/BangNiCMS`（不公开）。
> **构建好的镜像**已发布到 GHCR 公开镜像仓库：`ghcr.io/miaochi998/bangnicms-server / -web / -admin`。

## 🚀 一键部署

在你购买的全新 Ubuntu 22.04 VPS 上 SSH 登录后，运行：

```bash
# 海外服务器
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | bash

# 国内服务器（自动配 Docker 镜像加速）
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | bash -s -- --mirror=cn
```

脚本会自动完成：
- ✅ 安装 Docker + Compose Plugin
- ✅ 配置防火墙（ufw）放行 80/443/9443
- ✅ 创建数据目录 `/opt/bangnicms/data/`
- ✅ 部署 Portainer CE 并**自动初始化 admin 账号**（不会被 5 分钟未创建账号锁死）
- ✅ 预下载 BangNiCMS 应用模板

完成后浏览器打开 `https://你的IP:9443`，按提示部署 Stack。

## 📖 完整教程

**首次部署强烈推荐看这份小白教程（30~60 分钟带你从 0 走到上线）**：

👉 **[完整图文部署教程 →](docs/getting-started.md)**

涵盖：买服务器 / 域名 → DNS → 安全组 → SSH → 一键安装 → Portainer 部署 → 网站初始化 → AI 多语言翻译 → 日常运营 → 升级备份 → 故障排查。

## 📁 目录结构

```
BangNiCMS-deploy/
├── install-vps.sh                  # 一键安装脚本入口
├── portainer/
│   ├── template.json               # Portainer App Template（在 Settings → App Templates 添加）
│   ├── logo.svg                    # 模板 Logo
│   └── README.md                   # 模板设计说明
├── docker/
│   ├── docker-compose.prod.yml     # 生产部署 compose（Portainer 用）
│   ├── generate-secrets.sh         # 生成 3 个密钥的辅助脚本
│   └── caddy/Caddyfile             # Caddy 反向代理 + 自动 HTTPS 配置
└── docs/
    └── getting-started.md          # 小白完整图文教程
```

## 🔒 安全说明

- 本仓库**不包含任何业务源码**，仅含部署配置
- 三个关键密钥（POSTGRES_PASSWORD / JWT_SECRET / REVALIDATE_SECRET）由用户在部署时生成，不会出现在本仓库
- Portainer admin 密码由 `install-vps.sh` 在用户机器上随机生成并打印到 SSH 输出

## 🐛 报告问题

- **部署相关 Bug**（脚本/Compose/Caddy）：在本仓库提 [Issue](https://github.com/miaochi998/bncms-deploy/issues)
- **业务功能 Bug**（CMS 管理 / 前台展示等）：暂时也提到本仓库，我们会转交内部跟进

## 📜 License

MIT License。**部署配置文件可自由使用 / 修改 / 二次发行**。

业务镜像 `ghcr.io/miaochi998/bangnicms-*` 的使用受 BangNiCMS 主项目 License 约束。

---

**官方主页**（计划中）：`https://cms.bonnei.com`
**业务源码**（私有）：`https://github.com/miaochi998/BangNiCMS`

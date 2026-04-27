# BangNiCMS · 部署文件公开仓库

[![Deploy](https://img.shields.io/badge/deploy-docker--compose-blue)](docker-compose.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

本仓库存放 **BangNiCMS** 部署所需的公开文件（脚本 / Compose / 文档）。

> **业务源代码**位于私有仓库 `miaochi998/BangNiCMS`，**镜像**已发布到 GHCR 公开仓库 `ghcr.io/miaochi998/bangnicms-{server,web,admin}`。

## 🚀 部署只需 8 步

完整图文教程见 **[getting-started.md](getting-started.md)**。

简要流程：

1. **买 VPS + 域名**（Ubuntu 22.04 LTS / 4GB RAM / DNS 解析两条 A 记录）
2. **SSH 登录服务器**
3. **运行初始化脚本**（升级系统 + 装 Docker + 启动 Portainer，约 3 分钟）：
   ```bash
   curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/init-server.sh | bash
   ```
4. **浏览器打开 Portainer**（`https://你的IP:9443`）→ 设置 admin 账号
5. **创建 Stack**：复制本仓库 [docker-compose.yml](docker-compose.yml) 内容 → Portainer Stacks → Add stack → Web editor 粘贴
6. **填 5 个环境变量**（DOMAIN / ADMIN_EMAIL / 3 个密钥）
7. **Deploy**，等 6 个容器全 healthy
8. **浏览器访问域名** → 走安装向导 → 完成

## 📁 仓库结构

仅 4 个文件，简单透明：

```
bncms-deploy/
├── README.md              你正在看
├── init-server.sh         服务器初始化脚本（系统升级 + Docker + Portainer）
├── docker-compose.yml     完整 Stack 定义（自包含，Caddyfile 已内联）
└── getting-started.md     完整图文部署教程（小白可读）
```

## 🛡️ 安全说明

- 本仓库**完全不含业务源码**，仅含部署配置
- 三个关键密钥（POSTGRES_PASSWORD / JWT_SECRET / REVALIDATE_SECRET）由用户用 `openssl rand -hex 24` 自己生成，**绝不**经过本仓库
- Portainer admin 账号由用户在浏览器 Web UI 自己创建（5 分钟内），脚本**不会**自动设置密码

## 🐛 报告问题

- **部署 / 脚本 / Compose / Caddyfile**：在本仓库 [Issues](https://github.com/miaochi998/bncms-deploy/issues) 提
- **业务功能 Bug**（CMS / 前台 / 后台）：暂时也提到本仓库，我们会转交内部跟进

## 📜 License

MIT License。本仓库部署配置可自由使用 / 修改 / 二次发行。

镜像 `ghcr.io/miaochi998/bangnicms-*` 的使用受 BangNiCMS 主项目 License 约束。

---

**项目主页**（计划中）：`https://cms.bonnei.com`

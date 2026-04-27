# BangNiCMS 完整部署教程（小白版）

> **谁适合看这份教程**：第一次部署 BangNiCMS、不熟悉 Linux / Docker 的运营 / 老板 / 业务员。
>
> **预计耗时**：30~60 分钟（不含等待 DNS 生效的时间）
>
> **能做到什么**：拥有一个完整可运营的多语言外贸独立站，绑定 HTTPS 证书，含管理后台

---

## 部署流程总览（8 步）

| 步骤 | 做什么 | 大约耗时 |
|---|---|---|
| 1 | 买服务器 + 域名 + 配 DNS + 安全组放行端口 | 10~30 分钟 |
| 2 | SSH 登录服务器 | 1 分钟 |
| 3 | 运行初始化脚本（升级系统 + 装 Docker + 启动 Portainer） | 3~5 分钟 |
| 4 | 浏览器打开 Portainer，设置 admin 账号 | 2 分钟 |
| 5 | 创建 Stack（粘贴 docker-compose.yml） | 2 分钟 |
| 6 | 填 5 个环境变量并 Deploy | 5~10 分钟（拉镜像） |
| 7 | 验证 6 个容器全部 healthy + Caddy 申请到证书 | 2~5 分钟 |
| 8 | 浏览器访问域名，走安装向导 | 5 分钟 |

---

## 一、准备工作

### 1.1 买服务器（VPS）

#### 配置要求

| 项目 | 最低 | 推荐 |
|---|---|---|
| CPU | 2 核 | 2 核 |
| 内存 | 2 GB | 4 GB |
| 磁盘 | 30 GB SSD | 50 GB SSD |
| 操作系统 | **Ubuntu 22.04 LTS** | **Ubuntu 22.04 LTS** |
| 带宽 | 3 Mbps | 5 Mbps |

> **必须选 Ubuntu 22.04 LTS**，本教程仅在此系统验证过。

#### 服务商建议

- **海外业务为主（外贸独立站推荐）**：选香港 / 新加坡 / 美国机房，**域名免备案**
- **国内业务为主**：阿里云 / 腾讯云国内机房（**必须给域名做实名认证 + ICP 备案**）
- **预算有限**：雨云 / Vultr / DigitalOcean 月付 5~10 美元够用

#### 购买时一定要确认

- ✅ 操作系统选 **Ubuntu 22.04 LTS**（不是 20.04 也不是 24.04）
- ✅ 给一个公网 IP（弹性 IP 也行）
- ✅ 记下服务器的 **IP 地址 + root 密码**

---

### 1.2 买域名

任选一家：阿里云万网 / 腾讯云 DNSPod / Cloudflare / Namecheap / GoDaddy 都可以。

> 推荐 **Cloudflare**：DNS 解析速度快、免费 CDN、可配 DNS API 自动续证。

#### 购买后必须做的事

记下域名（如 `mysite.com`），等会儿要在 DNS 控制台配两条记录。

---

### 1.3 配置 DNS 解析（Cloudflare 示例）

打开域名 DNS 控制台，添加 **2 条 A 记录**：

| Type | Name | Content（你的服务器 IP） | TTL |
|---|---|---|---|
| A | `@` | `38.76.178.90` | Auto |
| A | `admin` | `38.76.178.90` | Auto |

> `@` 代表主域名（如 `mysite.com`），`admin` 代表子域名（`admin.mysite.com`）。

**保存后等 5~30 分钟生效**。

#### 验证 DNS 已生效

在你的**本地电脑**（Mac/Windows）打开终端，分别执行：

```bash
ping mysite.com
ping admin.mysite.com
```

**两条都必须返回你的服务器 IP**（如 `38.76.178.90`），才能继续下一步。

> ⚠️ 如果不返回正确 IP，**绝对不要继续**，否则后面 Caddy 申请 HTTPS 证书会失败。

---

### 1.4 云服务商安全组放行端口

进入云服务商控制台，找到你的服务器实例 → 安全组规则，**放行下面 4 个端口**：

| 端口 | 协议 | 用途 |
|---|---|---|
| 22 | TCP | SSH 登录 |
| 80 | TCP | HTTP（Caddy 申请证书 + 跳转 HTTPS） |
| 443 | TCP/UDP | HTTPS / HTTP3 |
| 9443 | TCP | Portainer 管理面板 |

> 雨云 / DigitalOcean / Vultr 默认全开，**通常无需操作**；阿里云 / 腾讯云**必须手动放行**，否则浏览器无法访问。

---

## 二、SSH 登录服务器

### 2.1 选个 SSH 工具

| 系统 | 推荐工具 |
|---|---|
| Mac / Linux | 自带 Terminal（直接 `ssh root@IP`）|
| Windows | [Tabby](https://tabby.sh/)（推荐）/ MobaXterm / PowerShell（Windows 10+ 自带 ssh） |

### 2.2 登录命令

```bash
ssh root@你的服务器IP
```

例：`ssh root@38.76.178.90`

输入 `yes`（首次连接确认指纹）→ 输入服务器 root 密码 → 看到形如 `root@xxx:~#` 的提示符即登录成功。

---

## 三、运行初始化脚本

**复制下面这条命令粘贴到 SSH 窗口，回车执行**：

#### 海外服务器（推荐）：

```bash
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/init-server.sh | bash
```

#### 国内服务器（自动配 Docker 镜像加速）：

```bash
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/init-server.sh | bash -s -- --mirror=cn
```

### 脚本会做 3 件事（约 3~5 分钟）

1. **升级系统软件包**（apt update + upgrade）
2. **安装 Docker**（官方 get.docker.com 脚本）
3. **配置防火墙**（ufw 放行 22 / 80 / 443 / 9443）+ **创建数据目录** `/opt/bangnicms/data` + **启动 Portainer CE**

### 脚本结束后会显示

```
==============================================================
  🎉  服务器初始化完成！
==============================================================
  Docker      : Docker version 27.x.x
  Portainer   : https://你的IP:9443
  数据目录    : /opt/bangnicms/data
  ...
```

**记下 Portainer URL**，下一步要用。

---

## 四、设置 Portainer admin 账号（5 分钟内必须完成）

> ⏱️ **重要**：Portainer 启动后 **5 分钟内必须创建 admin 账号**，否则会进入"安全锁定"状态需要重启容器。

### 4.1 浏览器打开 Portainer

地址栏输入：

```
https://你的服务器IP:9443
```

例：`https://38.76.178.90:9443`

### 4.2 跳过证书警告

会弹出**"您的连接不是私密连接"**警告（因为 Portainer 用自签证书，不是给你网站用的）。

- Chrome / Edge：点 **高级 → 继续访问 38.76.178.90（不安全）**
- Safari：点 **显示详细信息 → 访问此网站**

### 4.3 创建 admin 账号

看到 **"Create new administrator user"** 页面：

| 字段 | 填什么 |
|---|---|
| Username | `admin`（也可以填别的） |
| Password | **至少 12 位**，必须含**大写 + 小写 + 数字 + 特殊字符**（如 `MySecure@2026Pass`）|
| Confirm Password | 与上面一致 |

点 **Create user**。

### 4.4 选择环境

进入欢迎页 → 点 **Get Started** → 选 **local**（本地 Docker 环境）→ 进入 Dashboard。

> 此时左下角能看到 1 个容器（Portainer 自己）+ 1 个 Volume。**记住你刚设的密码**！

---

## 五、创建 BangNiCMS Stack（粘贴 docker-compose.yml）

### 5.1 进入 Add stack 页面

1. 左侧菜单 → **Stacks**（堆栈）
2. 右上角 → **+ Add stack**
3. **Name** 字段填：`bangnicms`
4. **Build method** 选 **Web editor**

### 5.2 复制 docker-compose.yml 内容

打开浏览器新标签页访问：

```
https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/docker-compose.yml
```

**全选 → 复制全部内容**（约 250 行）。

### 5.3 粘贴到 Web editor

回到 Portainer 页面，**粘贴到 Web editor 输入框**（替换默认的注释内容）。

---

## 六、填 5 个环境变量并 Deploy

### 6.1 生成 3 个密钥

回到 SSH 窗口，**执行下面 3 条命令各一次**，每次输出一串 48 位随机字符串：

```bash
echo "POSTGRES_PASSWORD = $(openssl rand -hex 24)"
echo "JWT_SECRET = $(openssl rand -hex 24)"
echo "REVALIDATE_SECRET = $(openssl rand -hex 24)"
```

输出示例：

```
POSTGRES_PASSWORD = 2c4f...（48 位）
JWT_SECRET = 8a9b...（48 位）
REVALIDATE_SECRET = e1f2...（48 位）
```

**立即把这 3 行复制到密码管理器或备忘录**。丢了需要重置数据库、业务数据会丢失！

### 6.2 在 Portainer 表单底部填环境变量

回到 Portainer 的 Add stack 页面，**滚动到 Web editor 下方**找到 **Environment variables** 区域。

点 **Add environment variable** 5 次，逐行填：

| Name | Value |
|---|---|
| `DOMAIN` | 你的域名（不带 `https://` 不带 `www`，例 `mysite.com`） |
| `ADMIN_EMAIL` | 你的常用邮箱（用于 Let's Encrypt 证书续期通知） |
| `BANGNICMS_POSTGRES_PASSWORD` | 上面生成的第 1 个密钥 |
| `BANGNICMS_JWT_SECRET` | 上面生成的第 2 个密钥 |
| `BANGNICMS_REVALIDATE_SECRET` | 上面生成的第 3 个密钥 |

### 6.3 部署

滚动到页面底部 → 点 **Deploy the stack**。

按钮会变成 **Deployment in progress...**（部署中），然后：

- **第 1~3 分钟**：拉取镜像（postgres / redis / server / web / admin / caddy 共 6 个，约 1.5 GB）
- **第 3~5 分钟**：启动容器 + 初始化数据库
- **第 5~8 分钟**：Caddy 向 Let's Encrypt 申请 HTTPS 证书

部署成功后会跳转回 Stacks 列表，显示 `bangnicms` 状态为 **Active**。

---

## 七、验证 6 个容器全部 healthy

### 7.1 进入 Containers 列表

左侧菜单 → **Containers** → 看到 6 个容器：

| 容器名 | 期望状态 |
|---|---|
| bangnicms-postgres | healthy ✅ |
| bangnicms-redis | healthy ✅ |
| bangnicms-server | healthy ✅ |
| bangnicms-web | running |
| bangnicms-admin | running |
| bangnicms-caddy | running |

> Postgres / Redis / Server 都有 healthcheck 所以显示 **healthy**；Web / Admin / Caddy 显示 **running** 即正常。

### 7.2 如果 caddy 一直不 running

**最常见原因**：DNS 没生效或安全组没放行 80/443，导致 Caddy 无法向 Let's Encrypt 验证域名。

诊断：

```bash
docker logs bangnicms-caddy --tail 60
```

看到 `obtained certificate` → 成功；看到 `timeout` / `connection refused` → 检查 DNS 和安全组。

### 7.3 验证 HTTPS 证书已签发

```bash
curl -I https://你的域名
```

期望看到 `HTTP/2 200` 或 `HTTP/2 308`（重定向）。如果看到 `SSL handshake failure` → 等 1 分钟再试，Caddy 还在签发。

---

## 八、浏览器访问域名，走安装向导

### 8.1 访问后台

```
https://admin.你的域名
```

例：`https://admin.mysite.com`

会自动跳转到 `/install` 安装向导。

### 8.2 安装向导 5 步

| 步骤 | 做什么 |
|---|---|
| Step 1 · 环境检查 | 自动检测数据库 / Redis / 存储目录 → 全绿点 **Next** |
| Step 2 · 数据库迁移 | 点 **Run migrations** 等 30 秒 → 全绿点 **Next** |
| Step 3 · 创建管理员 | 设站点超管账号（**这个账号管业务，不是 Portainer 那个**）：邮箱 / 用户名 / 至少 8 位密码 |
| Step 4 · 站点配置 | 填站点名称 / 默认语言（zh-CN 或 en）→ 点 **Next** |
| Step 5 · 示例数据 | **二选一**：<br>• **Import sample data**（推荐首次部署）：自动创建 12 个产品 / 21 篇文章 / 10 个主页模块 / 三语 i18n 字典<br>• **Skip and start empty**：完全空站，所有内容自己填 |

### 8.3 完成

进入后台 Dashboard → 浏览器访问 `https://你的域名` 看到首页 → **部署完成 🎉**

---

## 九、常见问题排查

### 9.1 Portainer 5 分钟超时锁定

显示 `Instance timed out for security purposes`。

**修复**：

```bash
docker rm -f portainer
docker volume rm portainer_data
docker run -d --name portainer --restart=unless-stopped \
  -p 9000:9000 -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

然后 **5 分钟内**重新打开 Portainer 创建账号。

### 9.2 Caddy 申请证书失败

**根因 1**：DNS 没生效 → 等 5~30 分钟后重启 caddy 容器（Portainer → Containers → bangnicms-caddy → Restart）

**根因 2**：80/443 安全组没放行 → 在云控制台补放行后重启 caddy

**根因 3**：Let's Encrypt 限流（同域名 1 周内申请超过 5 次失败）→ 等 1 周或换域名

### 9.3 镜像拉取慢 / 拉取失败

国内服务器走 ghcr.io 偶尔慢。如果 6 分钟过去还在 "downloading"，**强制改用国内代理**：

修改 `docker-compose.yml`，把所有 `ghcr.io/miaochi998/bangnicms-*` 改成：
```
ghcr.nju.edu.cn/miaochi998/bangnicms-*
```
（南京大学镜像代理）然后 Stacks → Update。

### 9.4 后台访问 502 Bad Gateway

server 容器还没启动完。等 1~2 分钟刷新。如果一直 502：

```bash
docker logs bangnicms-server --tail 100
```

把错误日志发到 GitHub Issue。

### 9.5 忘记安装向导设置的超管密码

```bash
docker exec -it bangnicms-postgres psql -U bangnicms -d bangnicms \
  -c "UPDATE \"User\" SET password='\$argon2id\$v=19\$m=65536,t=3,p=4\$placeholder' WHERE role='SUPER_ADMIN';"
```

然后访问 `https://admin.你的域名/forgot-password` 重置。

### 9.6 想完全重新部署（清空所有数据）

```bash
docker compose -p bangnicms down -v
rm -rf /opt/bangnicms/data
```

然后回到第 5 步重新创建 Stack。

---

## 十、获取帮助

- **GitHub Issues**：<https://github.com/miaochi998/bncms-deploy/issues>
- **官方部署文档**：<https://github.com/miaochi998/bncms-deploy>

提 Issue 时请附：版本号、操作系统、操作步骤、错误日志（`docker logs <container> --tail 100`）。

---

## 附录 A：完整命令速查

```bash
# === 服务器初始化（一次性）===
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/init-server.sh | bash

# === 国内服务器初始化 ===
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/init-server.sh | bash -s -- --mirror=cn

# === 生成 3 个密钥 ===
echo "POSTGRES_PASSWORD = $(openssl rand -hex 24)"
echo "JWT_SECRET = $(openssl rand -hex 24)"
echo "REVALIDATE_SECRET = $(openssl rand -hex 24)"

# === 查看容器状态 ===
docker ps

# === 查看某个容器日志 ===
docker logs bangnicms-server --tail 100
docker logs bangnicms-caddy --tail 60

# === 重启某个容器 ===
docker restart bangnicms-caddy

# === 查看容器资源占用 ===
docker stats

# === 数据备份（postgres）===
docker exec bangnicms-postgres pg_dump -U bangnicms bangnicms > backup-$(date +%Y%m%d).sql

# === 数据恢复 ===
cat backup-20260427.sql | docker exec -i bangnicms-postgres psql -U bangnicms bangnicms
```

## 附录 B：版本对应表

| 文档版本 | BangNiCMS 版本 | docker-compose.yml 默认镜像 tag |
|---|---|---|
| v2.0（当前）| 0.2.2 | `:0.2.2` |

升级到新版本：修改 `docker-compose.yml` 里所有 `:0.2.2` → 新版本号，然后 Portainer Stack 点 **Update** 即可。

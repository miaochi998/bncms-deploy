# BangNiCMS 完整部署教程（小白版）

> **适用版本**：v0.2.2 及以上
> **预计耗时**：30~60 分钟（含等待镜像拉取 + 证书签发）
> **目标读者**：完全不懂技术的运营 / 老板 / 外贸业务员，第一次自己部署一套外贸独立站
> **服务器要求**：**全新购买、未做任何配置**的云主机（Ubuntu 22.04 LTS 推荐）

本教程会**手把手**带你从"刚买完服务器"走到"网站正式上线"，过程中你只需要：

1. 复制粘贴命令（每条都告诉你"在哪粘贴"）
2. 在网页上点几下按钮（每个按钮都有截图标注）
3. 填几个表单（每个字段都告诉你填什么）

**不需要懂**：Linux 命令、Docker、什么是反向代理、什么是 SSL 证书。这些 BangNiCMS 自动帮你搞定。

---

## 目录

1. [准备工作](#一准备工作)
   - 1.1 [买一台云服务器](#11-买一台云服务器)
   - 1.2 [买一个域名](#12-买一个域名)
   - 1.3 [配置 DNS 解析](#13-配置-dns-解析)
   - 1.4 [打开云服务商【安全组】](#14-打开云服务商安全组放行端口)
2. [登录服务器](#二登录服务器)
3. [一键安装基础环境](#三一键安装基础环境)
4. [Portainer 部署网站](#四portainer-部署网站)
5. [网站初始化向导](#五网站初始化向导5-步搞定)
6. [配置 AI 助手 + 多语言翻译](#六配置-ai-助手--多语言翻译)
7. [日常运营：内容管理](#七日常运营内容管理)
8. [系统升级 + 数据备份](#八系统升级--数据备份)
9. [常见问题排查](#九常见问题排查)

---

## 一、准备工作

部署一个完整的 BangNiCMS 站点，你需要 **3 样东西**：

| 物品 | 大概花费 | 在哪买 |
|---|---|---|
| 云服务器（VPS） | 30~80 元/月 | 阿里云 / 腾讯云 / 雨云 / Vultr / DigitalOcean |
| 一个域名 | 50~100 元/年 | 阿里云 / 腾讯云 / Namecheap / Cloudflare |
| 一个邮箱地址 | 免费 | QQ 邮箱 / Gmail 都行 |

下面逐个准备。

### 1.1 买一台云服务器

#### 配置要求

| 项目 | 最低 | 推荐 |
|---|---|---|
| CPU | 2 核 | 2 核 |
| 内存 | 2 GB | 4 GB |
| 磁盘 | 30 GB SSD | 50 GB SSD |
| 操作系统 | **Ubuntu 22.04 LTS** | **Ubuntu 22.04 LTS** |
| 带宽 | 3 Mbps | 5 Mbps |

> **强烈建议选 Ubuntu 22.04 LTS**，本教程基于此系统验证；其他系统（CentOS/Debian）也能用但出问题时不易排错。

#### 服务商建议

- **国内业务为主**：选阿里云 / 腾讯云国内机房（**必须给域名做实名认证**才能解析国内服务器）
- **海外业务为主（外贸独立站推荐）**：选香港 / 新加坡 / 美国机房（域名免备案）
- **预算有限**：Vultr / DigitalOcean 5 美元/月套餐够用
- **国内访问 + 海外业务**：阿里云轻量香港 / 腾讯云轻量香港，约 30 元/月

#### 购买时一定要做的事

1. **操作系统选 Ubuntu 22.04 LTS**（不要选 Ubuntu 24 / Debian / CentOS）
2. **记下** 公网 IP 地址（4 段数字，例如 `38.76.178.90`）
3. **记下** root 密码（或下载 SSH 密钥）

> ⚠️ **如果服务器是别人帮你装过其他东西的，请重置成"默认 Ubuntu 22.04"**，避免冲突。

### 1.2 买一个域名

#### 选什么后缀？

- **`.com`** —— 国际通用，外贸首选（约 70 元/年）
- **`.net` / `.cn`** —— 备选
- **`.xyz` / `.top`** —— 便宜（约 10 元/年），但企业感弱

#### 在哪买？

- **国内服务器** → 必须在阿里云 / 腾讯云买（方便走备案流程）
- **海外服务器** → Cloudflare（最便宜 + 自带免费 CDN，强烈推荐）/ Namecheap / 阿里云国际版

#### 一定要做的事

记下你的域名（例如 `mysite.com`）。下面假设你的域名就是 `mysite.com`，请把所有出现的 `mysite.com` 替换成**你自己的域名**。

### 1.3 配置 DNS 解析

DNS 解析就是告诉互联网："访问 `mysite.com` 时，请连接到我这台服务器（IP: 38.76.178.90）"。

#### 你需要添加 **2 条 A 记录**：

| 记录类型 | 主机记录 | 记录值（你的服务器 IP） |
|---|---|---|
| A | `@` | `38.76.178.90` |
| A | `admin` | `38.76.178.90` |

> `@` 代表"根域"（即 `mysite.com` 本身），`admin` 是子域（即 `admin.mysite.com`）。
>
> BangNiCMS 用主域显示前台网站，用 `admin.` 子域显示后台管理系统。

#### 操作示例（以 Cloudflare 为例）

1. 登录 Cloudflare → 选中你的域名 → 左侧菜单 **DNS** → **Records**
2. 点 **Add record**：
   - Type: **A**
   - Name: `@`（输入 `@` 或 `mysite.com`）
   - IPv4 address: 你的服务器 IP（如 `38.76.178.90`）
   - Proxy status: **DNS only**（橙色云朵关掉，灰色才对）⚠️ 重要
   - 点 Save
3. 再点 **Add record**：
   - Type: **A**
   - Name: `admin`
   - IPv4 address: 同样的服务器 IP
   - Proxy status: **DNS only**
   - 点 Save

#### 验证 DNS 生效

打开手机 4G（关 WiFi）浏览器访问 `http://你的域名`，看看是否能 ping 到你的服务器（即使页面报错也算成功，关键是浏览器没说"找不到服务器"）。

或者在电脑命令行执行：
```bash
ping mysite.com
ping admin.mysite.com
```
两条都应该返回你服务器的 IP。

> ⚠️ **DNS 全球生效需要 5~30 分钟**，刚配好可能还没生效，先继续下一步，等会儿就好了。

### 1.4 打开云服务商【安全组】放行端口

服务器有两道"门"：

1. **服务器内部防火墙**（Linux 自带的 ufw）—— BangNiCMS 安装脚本会自动配置
2. **云服务商外部安全组** —— 这道门**必须你自己打开**，否则即使内部开了也访问不到！

#### 需要放行的端口

| 端口 | 用途 |
|---|---|
| **22** | SSH 远程登录（你登服务器要用） |
| **80** | HTTP 网站（Caddy 申请证书 + 自动跳转 HTTPS） |
| **443** | HTTPS 网站（最终用户访问） |
| **9443** | Portainer 管理界面（你用来部署 + 维护） |

#### 操作示例

**阿里云**：进入 ECS 实例 → 安全组规则 → 添加入方向 → 协议 TCP → 端口 `22,80,443,9443` → 授权对象 `0.0.0.0/0` → 保存

**腾讯云**：进入云服务器 → 防火墙 → 添加规则 → 协议 TCP → 端口同上 → 来源 `0.0.0.0/0` → 保存

**Vultr / DigitalOcean / 雨云**：默认全部端口放行，无需操作

> ⚠️ 这一步最容易被忽略！如果后面访问不到 Portainer 或网站，**第一时间检查这里**。

---

## 二、登录服务器

### 2.1 选择 SSH 工具（推荐 Tabby）

Windows / Mac 用户推荐安装 **Tabby**（免费、好看、稳定）：

- 下载地址：<https://tabby.sh/>

也可以用：
- Windows：自带 PowerShell（直接 `ssh root@IP`）/ PuTTY
- Mac：自带终端（直接 `ssh root@IP`）

### 2.2 第一次登录

打开 Tabby（或终端）执行：

```bash
ssh root@你的服务器IP
```

例如：
```bash
ssh root@38.76.178.90
```

第一次会问 `Are you sure you want to continue connecting (yes/no)?` 输入 `yes` 回车。

然后输入你买服务器时设置的 root 密码（**输入时不显示任何字符**，是正常的，输完直接回车）。

成功后你会看到类似：
```
Welcome to Ubuntu 22.04 LTS
...
root@server:~#
```

恭喜，你已经登录服务器了！

---

## 三、一键安装基础环境

### 3.1 运行一键脚本

复制下面这条命令粘贴到 SSH 窗口，**回车执行**：

#### 海外服务器（推荐）：

```bash
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | bash
```

#### 国内服务器（自动配 Docker 加速器）：

```bash
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | bash -s -- --mirror=cn
```

> 如果下载这个脚本本身就超时（GitHub 在国内偶尔慢），改用：
> ```bash
> curl -fsSL https://gitee.com/miaochi998/bncms-deploy/raw/main/install-vps.sh | bash -s -- --mirror=cn
> ```

### 3.2 等待 3~5 分钟

脚本会自动完成：

- ✅ 安装 Docker
- ✅ 配置防火墙（ufw）放行 80/443/9443
- ✅ 创建数据目录 `/opt/bangnicms/data/`
- ✅ 启动 Portainer（容器管理工具）**并自动初始化 admin 账号**
- ✅ 下载 BangNiCMS 应用模板

期间你会看到大量绿色和黄色日志输出，**只要没出现红色 ERROR 都是正常的**。

### 3.3 记下 Portainer admin 密码 ⚠️ 重要！

脚本最后会输出一段类似这样的信息：

```
==============================================================
  🎉  BangNiCMS 基础环境安装完成！
==============================================================

  Docker      : 27.5.1
  Portainer   : https://38.76.178.90:9443
  数据目录    : /opt/bangnicms/data

  Portainer admin 账号（请妥善保存并在首次登录后修改密码）：
    用户名：admin
    密码  ：xK7m@Lq2P!9wYzN3       ← 这里是你自己的，每次不一样

  下一步：
  --------------------------------------------------------------
  1) 浏览器打开 https://38.76.178.90:9443
  2) 用上面的 admin / 密码登录（已自动初始化，不会被锁死）
  ...
```

**立即把"用户名 + 密码"复制到密码管理器或备忘录！** 关掉 SSH 后这段文字就再也看不到了（虽然密码本身保留在服务器内）。

> 💡 这是 v0.2.2 起新增的特性：以前 Portainer 要求你 5 分钟内打开网页创建账号，超时就锁死。现在脚本帮你自动初始化好了，**永不锁死**。

---

## 四、Portainer 部署网站

### 4.1 打开 Portainer

浏览器访问 `https://你的服务器IP:9443`（注意是 **https**，不是 http）。

会弹出**"您的连接不是私密连接"**警告，这是因为 Portainer 用的是自签证书（不是给你的网站用的，给你的网站会用 Let's Encrypt）。

点 **高级 → 继续访问 38.76.178.90（不安全）**。

### 4.2 登录

- 用户名：`admin`
- 密码：上一步记下的那个 16 位密码

> 第一次登录后**强烈建议**点右上角头像 → My account → 修改成你自己记得的密码。

### 4.3 添加 BangNiCMS 应用模板

1. 左侧菜单 → **Settings** → **App Templates**
2. URL 输入框填：
   ```
   https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/portainer/template.json
   ```
3. 点 **Save Settings**
4. 应该看到提示 "Settings have been updated successfully"

### 4.4 部署 BangNiCMS Stack

1. 左侧菜单 → **App Templates**
2. 找到 **"BangNiCMS 外贸独立站"**（带 BangNiCMS Logo），点击
3. 表单填写：

| 字段 | 填什么 | 示例 |
|---|---|---|
| **Stack name** | 保持默认 `bangnicms` | `bangnicms` |
| **DOMAIN** | 你的域名（不带 https:// 不带 www） | `mysite.com` |
| **ADMIN_EMAIL** | 你的常用邮箱（用于 Let's Encrypt 证书续期通知） | `you@email.com` |
| **APP_VERSION** | 保持默认（最新稳定版） | `0.2.2` |
| **BANGNICMS_POSTGRES_PASSWORD** | 数据库密码（**点 Generate 自动生成**） | （随机 30 字符） |
| **BANGNICMS_JWT_SECRET** | 登录加密密钥（**点 Generate**） | （随机 30 字符） |
| **BANGNICMS_REVALIDATE_SECRET** | 缓存刷新密钥（**点 Generate**） | （随机 30 字符） |
| **DATA_ROOT** | 数据存储路径，保持默认 | `/opt/bangnicms/data` |
| **API_VERSION_SEGMENT** | 保持默认 | `2026-04` |
| **BANGNICMS_SITE_NAME** | 你的网站名（后续可改） | `My Foreign Trade Site` |
| **BANGNICMS_DEFAULT_LANGUAGE_CODE** | 默认语言 | `zh-CN`（如主用户是中文）或 `en`（如主用户是外国人） |
| **BANGNICMS_URL_STRATEGY** | URL 策略，保持默认 | `locale-prefix` |
| **PORTAINER_URL** | Portainer 内网地址，保持默认 | `https://portainer:9443` |
| **PORTAINER_API_KEY** | 暂时**保持默认值**，部署完后再回来改（详见 4.6） | （留空或保持默认） |
| **PORTAINER_STACK_ID** | 暂时填 `1`，部署后再改 | `1` |
| **PORTAINER_ENDPOINT_ID** | 保持默认 | `3` |

> 💡 **三个密钥（PASSWORD / JWT_SECRET / REVALIDATE_SECRET）非常重要**，丢了就需要重置。请把生成的值复制到密码管理器！

4. 滚动到表单底部 → 点 **Deploy the stack**

### 4.5 等待 3~10 分钟

Portainer 会自动完成：

- 拉取 6 个 Docker 镜像（postgres、redis、server、web、admin、caddy）
- 启动数据库 + 应用
- Caddy 向 Let's Encrypt 申请 HTTPS 证书

期间页面会显示 "Stack is being deployed..."，部署完成后可以在左侧 **Containers** 看到 6 个容器全部 **running** 状态：

```
bangnicms-postgres-1   running (healthy)
bangnicms-redis-1      running (healthy)
bangnicms-server-1     running (healthy)
bangnicms-web-1        running (healthy)
bangnicms-admin-1      running (healthy)
bangnicms-caddy-1      running
```

> ⚠️ 如果某个容器 30 秒内反复重启，点击它查看 Logs；常见错误见[第九节排查](#九常见问题排查)。

### 4.6 创建 Portainer API Token（用于"系统升级"功能）

> 这一步可选，但**强烈建议做**，否则后台的"系统升级"按钮无法工作。

1. Portainer 右上角头像 → **My account**
2. 滚动到 **Access tokens** → 点 **Add access token**
3. Description 填：`bangnicms-upgrade`
4. 点 **Add access token** → **复制生成的 Token**（只显示一次！）
5. 左侧菜单 → **Stacks** → 点 `bangnicms` → 点 **Editor** 标签
6. 滚动到 **Environment variables** 区域
7. 把 `PORTAINER_API_KEY` 改成上一步复制的 Token
8. 把 `PORTAINER_STACK_ID` 改成 Stack 详情页 URL 中的数字（例如 URL 是 `/stacks/1` 就填 `1`）
9. 点 **Update the stack** → 等待容器重启

---

## 五、网站初始化向导（5 步搞定）

### 5.1 打开向导

浏览器访问：`https://admin.你的域名/install`

例如：`https://admin.mysite.com/install`

> 如果显示"无法访问"或"证书错误"：
> - 检查 DNS 是否生效（`ping admin.你的域名`）
> - 等 1~2 分钟（Caddy 在申请证书）
> - 检查云服务商安全组 80/443 是否放行

### 5.2 第 1 步：环境检查

页面自动检测，5 项全绿就能继续：

- ✅ Node.js 版本（≥ 20）
- ✅ PostgreSQL 连接正常
- ✅ Redis 连接正常
- ✅ 存储目录可写
- ✅ Prisma migration 已应用

点 **下一步**。

### 5.3 第 2 步：数据库迁移

点 **开始迁移** → 几秒钟后看到 "Already applied 41 migrations" → 自动进入第 3 步。

### 5.4 第 3 步：创建超级管理员

| 字段 | 填什么 |
|---|---|
| 用户名 | `admin`（或你想要的用户名） |
| 密码 | 至少 6 位，**记到密码管理器** |
| 邮箱（可选） | 你的常用邮箱 |
| 显示名（可选） | "超级管理员" |

点 **创建管理员** → 自动进入第 4 步。

### 5.5 第 4 步：站点基础信息

| 字段 | 填什么 |
|---|---|
| 站点名称 | 你的网站标题（前台 Logo 旁会显示）|
| 站点描述 | 一句话介绍（用于 SEO） |
| 默认语言 | 简体中文 / English（**保存后不能改！**） |
| URL 策略 | 路径前缀（`/en /ja`），保持默认 |
| 站点 Host | 完整 URL：`https://mysite.com` |

点 **保存站点信息** → 自动进入第 5 步。

### 5.6 第 5 步：示例数据 + 完成

这一步有 **2 种选择**：

#### 选项 A：导入示例数据（推荐新手）

点 **导入示例数据** → 系统会自动创建：
- 12 个示例产品
- 21 篇文章（4 行业洞察 + 5 FAQ + 8 新闻 + 4 案例）
- 10 个下载资料
- 7 个静态页面（关于我们、联系我们、工厂、品质、隐私、服务、Cookie）
- 头部 + 底部菜单（14 个菜单项）
- 首页主题模块（Hero / 信任条 / 精选产品 等 10 个模块）

完成后点 **完成安装**。

> 💡 **示例数据全部可在后台编辑/删除**，相当于给你一个"模板"做参考。新手强烈推荐选这个。

#### 选项 B：从空站开始（适合老手）

直接点 **完成安装** → 跳过示例数据。前台首页会显示"欢迎使用 BangNiCMS / 当前站点已完成初始化，首页内容尚未配置"。

后续你需要在后台依次创建：页面 → 产品 → 文章 → 菜单 → 主题模块 → 网站文字 等。

---

### 5.7 完成！

点击 **前往登录 →**，跳转到登录页面。

- 前台：`https://你的域名`
- 后台：`https://admin.你的域名`
- 登录用户名 / 密码：5.4 步创建的那个

---

## 六、配置 AI 助手 + 多语言翻译

BangNiCMS 内置了**多语言支持**（中 / 英 / 日 三语），但**日语翻译只有 107/342 条**（默认数据）。剩下 235 条**通过 AI 一键翻译完成**，不需要你手动翻译。

### 6.1 开通 AI 服务（任选一家）

推荐 3 家，按价格排序（便宜 → 贵）：

| 服务商 | 价格 | 注册地址 | 适合 |
|---|---|---|---|
| **DeepSeek** | 极便宜（翻 235 条 < 1 元） | <https://platform.deepseek.com> | 国内开发者首选 |
| **OpenAI** | 中等（约 5 美元/月） | <https://platform.openai.com> | 通用 |
| **Anthropic Claude** | 中等 | <https://console.anthropic.com> | 翻译质量最好 |

注册后充值 ≥ 10 元 → 进入 API Keys 页面 → 创建一个 API Key → **复制保存**（只显示一次）。

### 6.2 在后台配置 AI 助手

1. 后台 → 左侧菜单 → **AI 助手** → **配置**
2. 选择 Provider（DeepSeek / OpenAI / Anthropic）
3. 粘贴 API Key
4. 选择模型（推荐 `deepseek-chat` / `gpt-4o-mini` / `claude-3-5-haiku`）
5. 点 **保存** → **测试连接**（应该返回"连接成功"）

### 6.3 一键翻译多语言

1. 后台 → 左侧菜单 → **网站文字**（位于"快捷入口"或"语言管理"下方）
2. 顶部看到 3 个语言卡片：
   - 简体中文（默认源语言）：100% ✓
   - English：100% ✓
   - 日本語：约 31%（107/342）⚠️
3. 点击 **日本語** 卡片 → 弹出右上角 **AI 批量翻译** 按钮
4. 点击 → 弹出对话框 → 默认勾选"仅翻译未译的键" → 点 **开始翻译**
5. 等待 1~2 分钟 → 看到 "AI 翻译完成（日本語）成功 235 · 跳过 107 · 失败 0"
6. 翻译结果状态：**AI 待审核**（即用户可见但带"未审核"标记）
7. （可选）点 **批量审核** → 把 AI 译文标记为"已审核"

完成后日语卡片显示 100% ✓。前台访问 `https://mysite.com/ja` 可看到日语版网站。

> 💡 同样方法可以新增其他语言（韩语、法语、西班牙语等）：
> 1. **语言管理** → **新增语言** → 填 code（如 `ko`）+ 名称（한국어）+ 启用
> 2. 回到 **网站文字** → 选韩语 → AI 批量翻译

---

## 七、日常运营：内容管理

后台左侧菜单 21 个模块，最常用的是这几个：

### 7.1 站点设置

`后台 → 站点设置`

- **基础信息**：网站名、描述、Logo、Favicon
- **联系方式**：邮箱、电话、WhatsApp、地址（前台多处显示）
- **资质徽章**：ISO 9001 / CE / FCC / RoHS 等（前台 Header / Footer 显示）
- **SEO**：默认 SEO 标题、描述、关键词
- **上传与媒体设置**：最大文件大小、允许扩展名、视频缩略图等
- **SMTP**：邮件发送配置（询盘通知用）

> ⚠️ **最重要的事**：把示例数据里默认的"sales@bangnicms.com / 400-888-8888"改成**你自己的真实联系方式**！否则客户问询会发到不存在的邮箱。

### 7.2 产品管理

`后台 → 产品管理`

- **新建产品**：标题、产品标识（URL slug）、简介、详情、SEO、封面图、所属分类、相关产品、发布控制
- **多语言**：每个产品可以分别录入中/英/日译文
- **首页推荐**：勾选"加入首页精选产品"+ 排序权重
- **询盘**：客户在前台产品页可以"加入询盘车"批量询价

### 7.3 文章管理 / 下载管理 / 页面管理

操作模式与产品类似。

- **文章**：行业洞察 / FAQ / 新闻 / 案例研究
- **下载**：产品手册 PDF / 报价单 / 资质证书
- **页面**：关于我们 / 联系我们 / 工厂 / 品质 / 等独立页面

### 7.4 主题配置

`后台 → 主题配置`

控制前台首页的"模块化"内容：

| 模块 | 控制内容 |
|---|---|
| Hero | 首屏大图 + 标题 + 副标题 + 行动按钮 |
| 信任条 | "15 年制造经验"等 3 行短语 |
| 价值主张 | 6 项数据墙（年限 / 国家数 / 客户数 等） |
| 精选产品 | 首页展示哪些产品（手动指定 + 自动补齐） |
| 我们的优势 | 4 项核心优势 |
| 行业方案 | 按行业聚合的产品分类 |
| 行业洞察 | 首页展示的文章 |
| 常见问题 | 首页 FAQ |
| 行动号召 | 底部"立即询价"卡片 |
| 站点页头 / 页脚 | 顶部菜单 + 底部菜单 + 联系信息 |

每个模块可以**单独启用 / 禁用** + **拖拽排序**。

### 7.5 询盘管理

`后台 → 询盘管理`

客户在前台提交的所有询价单都会出现在这里：

- 状态：待处理 / 已查看 / 已回复 / 已关闭
- 来源：产品页 / 询盘车 / 联系页
- 配置 SMTP 后会有邮件通知

---

## 八、系统升级 + 数据备份

### 8.1 数据备份

`后台 → 数据备份`

- **手动备份**：点击"立即备份" → 几秒后下载 zip（含数据库 + 上传的图片视频）
- **定时备份**：建议设置每天凌晨 3:00 自动备份，保留 7 份
- **还原**：上传备份 zip → 一键还原（**会覆盖当前数据**！）

> ⚠️ **强烈建议**每周下载一份备份到你自己的电脑或网盘，防止服务器整体丢失。

### 8.2 系统升级

`后台 → 系统升级`

当我们发布新版本（如从 0.2.2 升到 0.3.0）时：

1. 进入升级页面 → 看到"有新版本可用"
2. **强烈建议**先点"立即备份"做一次手动备份
3. 点 **升级到 0.3.0** → 系统自动：
   - 拉取新镜像
   - 重启容器
   - 应用数据库迁移
4. 等 1~3 分钟 → 升级完成

如果升级失败：进入 Portainer → Stack → Editor → 把 `APP_VERSION` 改回旧版本 → Update → 一键回滚。

> ⚠️ 这个功能依赖 4.6 配置的 Portainer API Token。如果没配，"升级"按钮会提示"未配置升级权限"。

---

## 九、常见问题排查

### 9.1 浏览器访问 `https://mysite.com` 显示证书错误

**原因 1**：DNS 还没生效
- 解决：等 5~30 分钟，或手机 4G 测试

**原因 2**：Caddy 申请证书失败（常见！）
- 检查云服务商安全组 80/443 是否放行（这是最常见原因）
- 检查 DNS 是否真的指向你的服务器
- 在服务器 SSH 内运行 `docker logs bangnicms-caddy-1 --tail 50` 查看错误

### 9.2 Portainer 无法访问 / Stack 部署超时

- 检查 9443 端口是否在云服务商安全组放行
- 在 SSH 内 `docker ps` 查看 Portainer 是否运行：`docker ps | grep portainer`
- 重启：`docker restart portainer`

### 9.3 镜像拉取超时（"i/o timeout"）

国内服务器拉 Docker Hub 经常超时。SSH 内运行：

```bash
cat > /etc/docker/daemon.json <<'EOF'
{"registry-mirrors":["https://docker.m.daocloud.io","https://hub-mirror.c.163.com","https://docker.1ms.run"]}
EOF
systemctl restart docker
docker start portainer
```

然后 Portainer 内重新 deploy stack。

### 9.4 镜像 `ghcr.io/miaochi998/bangnicms-*` 拉取 401

GitHub 镜像默认私有，需要改公开（**仅作者首次发布需要做**，普通用户应该已经看到是公开的）。

如果你是项目维护者：
- 访问 <https://github.com/users/miaochi998/packages> → 点每个包 → Settings → Change visibility → Public

### 9.5 忘记后台超管密码

SSH 内执行：

```bash
docker exec -it bangnicms-server-1 node dist/scripts/reset-admin-password.js admin 新密码
```

（如果命令不存在，参考 `docs/troubleshooting/reset-admin-password.md`）

### 9.6 忘记 Portainer admin 密码

SSH 内执行：

```bash
docker rm -f portainer
docker volume rm portainer_data
# 重新跑一遍 install-vps.sh，密码会重新生成
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | bash
```

> ⚠️ 重置 Portainer 不会影响 BangNiCMS 网站数据（数据在 `/opt/bangnicms/data/` 不受影响）。

### 9.7 网站访问很慢

- **国内访问海外服务器** → 用 Cloudflare 套个 CDN（DNS 那里的橙色云朵打开）
- **图片加载慢** → 在站点设置里启用"图片自动压缩"
- **服务器负载高** → 升级到 4G 内存套餐

### 9.8 邮件通知不发送

- 检查 `站点设置 → SMTP` 是否填了正确的邮箱配置
- 国内服务器禁用 25 端口，改用 SMTP **465（SSL）** 或 **587（STARTTLS）**
- QQ 邮箱 / 163 邮箱密码用"授权码"，不是登录密码

---

## 十、获取帮助

- **GitHub Issues**：<https://github.com/miaochi998/bncms-deploy/issues>
- **官方文档**：<https://github.com/miaochi998/bncms-deploy/tree/main/docs>
- **完整版图文教程**（即将上线）：`https://cms.bonnei.com`（计划中的官方宣传站）

如果遇到本教程未覆盖的问题，请：

1. 先在 SSH 内 `docker logs bangnicms-server-1 --tail 100` 看错误日志
2. 把错误日志贴到 GitHub Issue
3. 同时提供：版本号、操作系统、操作步骤

---

## 附录 A：完整命令速查

```bash
# 一键安装（海外）
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | bash

# 一键安装（国内加速）
curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | bash -s -- --mirror=cn

# 查看所有容器
docker ps -a

# 查看某容器日志
docker logs bangnicms-server-1 --tail 100
docker logs bangnicms-caddy-1 --tail 50

# 重启某容器
docker restart bangnicms-server-1

# 重启整个 Stack（在 Portainer 内更方便）
cd /var/lib/docker/volumes/portainer_data/_data/compose/1
docker compose --env-file stack.env -f docker-compose.yml restart

# 查看磁盘占用
df -h
du -sh /opt/bangnicms/data/*

# 数据备份（手动）
tar czf bangnicms-backup-$(date +%Y%m%d).tar.gz /opt/bangnicms/data
```

---

## 附录 B：版本对应说明

| 文档版本 | 适配 BangNiCMS 版本 | 说明 |
|---|---|---|
| 1.0 | v0.2.2+ | 初版（Portainer 自动初始化 / Mixed Content 修复） |

---

**祝你部署顺利！🎉**

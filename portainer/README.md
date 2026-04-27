# Portainer 应用模板（PR11）

本目录为 Portainer "App Templates" 提供一键部署 BangNiCMS 的元数据。

## 文件清单

- `template.json` —— 模板聚合文件（Portainer Settings → App Templates → URL 直接指向此文件）
- `logo.svg` —— BangNiCMS 品牌占位 logo（128×128，可后续替换为正式品牌素材）
- `README.md` —— 本维护指引

## 托管 URL

- 主源：`https://raw.githubusercontent.com/miaochi998/BangNiCMS/main/infra/portainer/template.json`
- 备用源：暂无（后续若申请 `cms.bonnei.com` 等域名时同步到 `infra/scripts/install-vps.sh` 的 `BANGNICMS_TEMPLATE_URL_BACKUP`）

`infra/scripts/install-vps.sh` 已在第 7 步预下载主源模板到 `portainer_data` volume。

## 用户使用流程

1. 跑 `install-vps.sh` 一键安装好 Docker + Portainer
2. 浏览器打开 `https://<server-ip>:9443`
3. 创建管理员账号（30 秒内）
4. 顶部菜单 → Settings → App Templates → URL 填入主源 URL（默认已预下载，可改用本地路径）
5. 左侧菜单 → App Templates → 找到「BangNiCMS 外贸独立站」点击 Deploy
6. 表单按提示填写 → Deploy the stack
7. 等待 Caddy 颁发证书，访问 `https://${DOMAIN}` / `https://admin.${DOMAIN}`

## 模板字段设计要点

### 必填项（用户须自填）

- `DOMAIN` / `ADMIN_EMAIL`
- `BANGNICMS_POSTGRES_PASSWORD` / `BANGNICMS_JWT_SECRET` / `BANGNICMS_REVALIDATE_SECRET`
  - 推荐先在 SSH 中跑：
    ```bash
    bash <(curl -sSL https://raw.githubusercontent.com/miaochi998/BangNiCMS/main/infra/docker/generate-secrets.sh)
    ```
  - 输出 3 段 32 字符随机串复制粘贴到 Portainer 表单即可

### 自动填充（部署完成后）

- `PORTAINER_STACK_ID` —— server 容器启动时通过 Portainer API 自动发现 stack，写回数据库 `UpgradeConfig.portainerStackId`
- `PORTAINER_ENDPOINT_ID` —— 默认 1，多节点 swarm 集群才需调整

### 可选项（保留默认即可）

- `APP_VERSION`、`DATA_ROOT`、`API_VERSION_SEGMENT`、`BANGNICMS_SITE_NAME`、`BANGNICMS_DEFAULT_LANGUAGE_CODE`

## 维护更新

1. 修改 `template.json`（务必通过 `jq . template.json > /tmp/x && mv /tmp/x template.json` 校验 JSON 合法）
2. 提交 `main` 分支
3. GitHub raw CDN 在 5–10 分钟内全球刷新

## 本地调试

```bash
# 临时托管模板供 Portainer 拉取
cd infra/portainer
python3 -m http.server 18080

# Portainer Settings → App Templates → URL：
# http://host.docker.internal:18080/template.json
```

## 校验脚本

```bash
# JSON 合法性
jq . infra/portainer/template.json >/dev/null

# 字段必备项检查
jq '.templates[0] | {title, repository, env: (.env | length)}' infra/portainer/template.json
```

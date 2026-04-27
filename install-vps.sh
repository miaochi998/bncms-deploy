#!/usr/bin/env bash
# ============================================================
# BangNiCMS · VPS 一键初始化脚本（PR10 · 模块 G）
# 设计文档：docs/deployment/16-module-g-installer.md
# ------------------------------------------------------------
# 用法（干净的 Ubuntu / Debian / CentOS / Rocky）：
#   curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | sudo bash
#
# 国内用户（启用 Docker 加速器 + 中国镜像源）：
#   curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/install-vps.sh | sudo bash -s -- --mirror=cn
#
# 该脚本完成：
#   1. Docker Engine + Compose Plugin
#   2. 系统防火墙（ufw / firewalld）放行 22/80/443/9443
#   3. 数据目录 /opt/bangnicms/data/*（bind mount 用）
#   4. Portainer CE 容器（HTTPS 端口 9443）
#   5. 预下载 BangNiCMS 应用模板 JSON
#   6. 打印下一步引导
#
# 幂等：每步都检测已存在状态，重复运行不会报错
# ============================================================
set -euo pipefail

# ---------- 配置 ----------
INSTALLER_VERSION="1.1.0"
REPO_SLUG="${BANGNICMS_REPO_SLUG:-miaochi998/bncms-deploy}"
BRANCH="${BANGNICMS_BRANCH:-main}"
TEMPLATE_URL_PRIMARY="https://raw.githubusercontent.com/${REPO_SLUG}/${BRANCH}/portainer/template.json"
TEMPLATE_URL_BACKUP="${BANGNICMS_TEMPLATE_URL_BACKUP:-}"
DATA_ROOT="${DATA_ROOT:-/opt/bangnicms/data}"
USE_CN_MIRROR=0

# ---------- CLI 参数 ----------
for arg in "$@"; do
  case "$arg" in
    --mirror=cn) USE_CN_MIRROR=1 ;;
    --help|-h)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "未知参数：$arg" >&2
      exit 1
      ;;
  esac
done

# ---------- 日志辅助 ----------
log()  { printf '\033[1;32m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }

# ---------- 前置检查 ----------
if [[ $EUID -ne 0 ]]; then
  err "请以 root 运行（或使用 sudo bash install-vps.sh）"
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  err "无法识别操作系统（缺少 /etc/os-release）"
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
OS_ID="${ID:-unknown}"
OS_VERSION_ID="${VERSION_ID:-}"
OS_PRETTY="${PRETTY_NAME:-$OS_ID $OS_VERSION_ID}"

log "BangNiCMS VPS 安装程序 v${INSTALLER_VERSION}"
log "检测到系统：${OS_PRETTY}"
if [[ $USE_CN_MIRROR -eq 1 ]]; then
  log "已启用国内镜像加速（--mirror=cn）"
fi

case "$OS_ID" in
  ubuntu|debian|centos|rocky|rhel|almalinux) ;;
  *)
    warn "未严格测试过的发行版：$OS_ID，继续尝试..."
    ;;
esac

# ============================================================
# 1. 安装 Docker Engine
# ============================================================
if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
  log "Docker 已存在：$(docker --version)"
else
  log "开始安装 Docker..."
  if [[ $USE_CN_MIRROR -eq 1 ]]; then
    # 阿里云 Docker 一键安装脚本（国内友好）
    curl -fsSL https://get.docker.com | bash -s -- --mirror Aliyun
  else
    curl -fsSL https://get.docker.com | sh
  fi
  systemctl enable --now docker
fi

# ============================================================
# 2. Docker Compose Plugin
# ============================================================
if docker compose version >/dev/null 2>&1; then
  log "Docker Compose 已存在：$(docker compose version | head -1)"
else
  log "安装 Docker Compose Plugin..."
  case "$OS_ID" in
    ubuntu|debian)
      apt-get update -qq
      apt-get install -y docker-compose-plugin
      ;;
    centos|rocky|rhel|almalinux)
      yum install -y docker-compose-plugin || dnf install -y docker-compose-plugin
      ;;
    *)
      err "未知系统，无法自动安装 Compose Plugin。请参考 https://docs.docker.com/compose/install/"
      exit 1
      ;;
  esac
fi

# ============================================================
# 3. 国内镜像加速器（仅 --mirror=cn）
# ============================================================
if [[ $USE_CN_MIRROR -eq 1 ]]; then
  log "配置 Docker 国内镜像加速器..."
  mkdir -p /etc/docker
  # 只在首次写入；已有配置则保留用户的
  if [[ ! -f /etc/docker/daemon.json ]]; then
    cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF
    systemctl daemon-reload
    systemctl restart docker
  else
    warn "/etc/docker/daemon.json 已存在，跳过镜像加速配置（避免覆盖）"
  fi
fi

# ============================================================
# 4. 防火墙：放行 22 / 80 / 443 / 9443
# ============================================================
configure_firewall() {
  local ports=(22 80 443 9443)
  if command -v ufw >/dev/null 2>&1; then
    log "使用 ufw 配置防火墙..."
    for p in "${ports[@]}"; do
      ufw allow "${p}/tcp" >/dev/null 2>&1 || true
    done
    # HTTP/3（Caddy）
    ufw allow 443/udp >/dev/null 2>&1 || true
    ufw --force enable >/dev/null 2>&1 || true
  elif command -v firewall-cmd >/dev/null 2>&1; then
    log "使用 firewalld 配置防火墙..."
    systemctl enable --now firewalld >/dev/null 2>&1 || true
    for p in "${ports[@]}"; do
      firewall-cmd --permanent --add-port="${p}/tcp" >/dev/null 2>&1 || true
    done
    firewall-cmd --permanent --add-port=443/udp >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
  else
    warn "未检测到 ufw 或 firewalld，跳过本机防火墙配置"
    warn "请务必在【云服务商安全组】中放行 22/80/443/9443 端口"
  fi
}
configure_firewall

# ============================================================
# 5. 数据目录
# ============================================================
log "创建数据目录：${DATA_ROOT}"
mkdir -p \
  "${DATA_ROOT}/postgres" \
  "${DATA_ROOT}/redis" \
  "${DATA_ROOT}/storage/uploads" \
  "${DATA_ROOT}/storage/plugins" \
  "${DATA_ROOT}/storage/extensions" \
  "${DATA_ROOT}/storage/backups" \
  "${DATA_ROOT}/storage/runtime" \
  "${DATA_ROOT}/caddy/data" \
  "${DATA_ROOT}/caddy/config" \
  "${DATA_ROOT}/caddy/logs"

# 镜像内 nodejs 用户 UID/GID = 1001
chown -R 1001:1001 "${DATA_ROOT}/storage" || true
# postgres 用 999；redis 用 999（Alpine 镜像默认）
chown -R 999:999 "${DATA_ROOT}/postgres" "${DATA_ROOT}/redis" || true

# ============================================================
# 6. Portainer CE
# ============================================================
PORTAINER_IMAGE="portainer/portainer-ce:latest"
if [[ $USE_CN_MIRROR -eq 1 ]]; then
  PORTAINER_IMAGE="registry.cn-hangzhou.aliyuncs.com/portainer/portainer-ce:latest"
fi

# Portainer 自动初始化 admin 密码（避免首次访问 5 分钟内未创建账号被锁死）
#   - 用 htpasswd 生成 bcrypt 哈希文件，挂载到容器并通过 --admin-password-file 启动
#   - 密码：未指定 PORTAINER_ADMIN_PASSWORD 时随机生成 16 位强密码并打印到日志
#   - 用户登录后可在 Portainer UI 任意修改密码
PORTAINER_ADMIN_PASSWORD="${PORTAINER_ADMIN_PASSWORD:-}"
if [[ -z "$PORTAINER_ADMIN_PASSWORD" ]]; then
  PORTAINER_ADMIN_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^*_+=-' </dev/urandom | head -c 16 || true)"
  PORTAINER_ADMIN_PASSWORD="${PORTAINER_ADMIN_PASSWORD:-BangNiCMS@$(date +%s)}"
  PORTAINER_PASSWORD_GENERATED=1
else
  PORTAINER_PASSWORD_GENERATED=0
fi

if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
  log "Portainer 容器已存在，跳过创建（如忘记密码请：docker rm -f portainer && docker volume rm portainer_data，再重跑本脚本）"
else
  log "部署 Portainer CE（镜像：${PORTAINER_IMAGE}）..."
  docker volume create portainer_data >/dev/null

  # 用 httpd 镜像生成 bcrypt 哈希（极轻，所有平台通用，避免要求宿主机有 htpasswd / openssl passwd -B）
  log "生成 Portainer admin bcrypt 密码哈希..."
  PORTAINER_BCRYPT="$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin "$PORTAINER_ADMIN_PASSWORD" 2>/dev/null | cut -d: -f2)"
  if [[ -z "$PORTAINER_BCRYPT" ]]; then
    err "生成 bcrypt 哈希失败，请检查网络（需要拉取 httpd:2.4-alpine 镜像）"
    exit 1
  fi
  PORTAINER_PWD_FILE="/var/lib/docker/portainer_admin_password"
  printf '%s' "$PORTAINER_BCRYPT" > "$PORTAINER_PWD_FILE"
  chmod 600 "$PORTAINER_PWD_FILE"

  docker run -d \
    --name portainer \
    --restart=unless-stopped \
    -p 9443:9443 \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    -v "${PORTAINER_PWD_FILE}:/tmp/portainer_password:ro" \
    "${PORTAINER_IMAGE}" \
    --admin-password-file /tmp/portainer_password \
    >/dev/null

  log "Portainer 已启动，admin 账号已自动初始化"
fi

# ============================================================
# 7. 预下载应用模板 JSON
# ============================================================
TEMPLATE_VOLUME_PATH="/var/lib/docker/volumes/portainer_data/_data/bangnicms-template.json"
log "下载 BangNiCMS 应用模板..."
DOWNLOAD_OK=0
if curl -fsSL --max-time 30 "$TEMPLATE_URL_PRIMARY" -o "${TEMPLATE_VOLUME_PATH}.tmp" 2>/dev/null; then
  mv "${TEMPLATE_VOLUME_PATH}.tmp" "$TEMPLATE_VOLUME_PATH"
  DOWNLOAD_OK=1
  log "模板下载成功（主源）"
elif [[ -n "$TEMPLATE_URL_BACKUP" ]]; then
  warn "主源超时，尝试备用源..."
  if curl -fsSL --max-time 30 "$TEMPLATE_URL_BACKUP" -o "${TEMPLATE_VOLUME_PATH}.tmp" 2>/dev/null; then
    mv "${TEMPLATE_VOLUME_PATH}.tmp" "$TEMPLATE_VOLUME_PATH"
    DOWNLOAD_OK=1
    log "模板下载成功（备用源）"
  fi
fi

if [[ $DOWNLOAD_OK -eq 0 ]]; then
  warn "模板下载失败 —— 网络问题或模板尚未发布"
  warn "Portainer 仍可正常使用，稍后可在 Settings → App Templates 手动填入："
  warn "  ${TEMPLATE_URL_PRIMARY}"
fi

# ============================================================
# 8. 获取外网 IP（尽力而为）
# ============================================================
SERVER_IP=""
for svc in "https://api.ipify.org" "https://ifconfig.me" "https://ipinfo.io/ip"; do
  if ip=$(curl -fsSL --max-time 5 "$svc" 2>/dev/null); then
    SERVER_IP="$ip"
    break
  fi
done
if [[ -z "$SERVER_IP" ]]; then
  SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
SERVER_IP="${SERVER_IP:-<你的服务器 IP>}"

# ============================================================
# 9. 打印完成信息
# ============================================================
if [[ $PORTAINER_PASSWORD_GENERATED -eq 1 ]]; then
  PORTAINER_PWD_BLOCK="  Portainer admin 账号（请妥善保存并在首次登录后修改密码）：
    用户名：admin
    密码  ：${PORTAINER_ADMIN_PASSWORD}"
else
  PORTAINER_PWD_BLOCK="  Portainer admin 密码：使用了你传入的 PORTAINER_ADMIN_PASSWORD 环境变量"
fi

cat <<EOF

==============================================================
  🎉  BangNiCMS 基础环境安装完成！
==============================================================

  Docker      : $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
  Compose     : $(docker compose version --short 2>/dev/null || echo 'plugin')
  Portainer   : https://${SERVER_IP}:9443
  数据目录    : ${DATA_ROOT}

${PORTAINER_PWD_BLOCK}

  下一步：
  --------------------------------------------------------------
  1) 浏览器打开 https://${SERVER_IP}:9443
     （首次会提示“证书不安全”，点“高级 → 继续访问”即可）

  2) 用上面的 admin / 密码登录（已自动初始化，不会被锁死）

  3) 登录后进入 Settings → App Templates → 填入：
     ${TEMPLATE_URL_PRIMARY}
     （若 8 步已预下载成功，可直接使用 file:///data/bangnicms-template.json）

  4) 回到 App Templates 列表，找到“BangNiCMS 外贸独立站”点击部署
     按表单填入 DOMAIN / ADMIN_EMAIL / Portainer API Token 等即可

  ⚠️  重要提示
  --------------------------------------------------------------
  云服务商【安全组】也需要放行 80 / 443 / 9443 端口！
    • 阿里云：ECS 实例 → 安全组规则
    • 腾讯云：云服务器 → 防火墙
    • AWS   ：EC2 → Security Groups

  详细教程：https://github.com/${REPO_SLUG}/tree/${BRANCH}/docs/deployment
==============================================================

EOF

#!/usr/bin/env bash
# ============================================================
# BangNiCMS 服务器初始化脚本
# ------------------------------------------------------------
# 作用（仅 3 件事，与 BangNiCMS 业务无关）：
#   1) 升级系统（apt update + upgrade）
#   2) 安装 Docker（官方 get.docker.com 脚本）
#   3) 启动 Portainer CE（容器管理面板）
#
# 用法（在新购买的 Ubuntu 22.04 服务器上 SSH 执行一次即可）：
#   curl -fsSL https://raw.githubusercontent.com/miaochi998/bncms-deploy/main/init-server.sh -o /tmp/init.sh
#   nohup bash /tmp/init.sh </dev/null >/tmp/bncms-init.log 2>&1 &
#   tail -f /tmp/bncms-init.log
#   # 看到 "🎉 服务器初始化完成" 后 Ctrl+C 退出 tail
#
# 国内服务器（自动配 Docker 镜像加速），把最后一行 nohup 命令改为：
#   nohup bash /tmp/init.sh --mirror=cn </dev/null >/tmp/bncms-init.log 2>&1 &
#
# 为何用 nohup？apt upgrade 时 sshd 会重启导致 SSH 断开，nohup 防止脚本被 SIGHUP 杀掉。
#
# 完成后：浏览器打开 https://你的服务器IP:9443 → 5 分钟内创建 admin 账号
# ============================================================

set -euo pipefail

# 忽略 SIGHUP，避免 apt upgrade 重启 sshd 时脚本被杀
trap '' HUP

MIRROR_MODE="default"
for arg in "$@"; do
  case "$arg" in
    --mirror=cn) MIRROR_MODE="cn" ;;
  esac
done

log() { echo -e "\033[1;36m[$(date +%H:%M:%S)]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERR]\033[0m $1" >&2; }

# ============================================================
# 1) 检查环境
# ============================================================
if [[ $EUID -ne 0 ]]; then
  err "请用 root 运行（或 sudo bash init-server.sh）"
  exit 1
fi

if ! grep -qi 'ubuntu' /etc/os-release 2>/dev/null; then
  err "本脚本仅在 Ubuntu 22.04 LTS 上验证。其他系统请手动安装 Docker 和 Portainer。"
  exit 1
fi

log "BangNiCMS 服务器初始化 v2.1"
log "操作系统：$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"

# ============================================================
# 2) 升级系统（apt update + upgrade）
# ============================================================
log "[1/3] 升级系统软件包（约 2~5 分钟）..."
export DEBIAN_FRONTEND=noninteractive

# 停掉 Ubuntu 新机自带的 unattended-upgrades，避免和我们抢 dpkg 锁
log "  停用 unattended-upgrades 服务避免抢锁..."
systemctl stop unattended-upgrades.service apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
systemctl disable unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

# 等待已经在跑的 apt/dpkg 进程结束（最多 10 分钟）
log "  等待已有 apt/dpkg 进程结束（首次开机时系统会自动跑后台升级）..."
for i in $(seq 1 60); do
  if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
    break
  fi
  if [ $i -eq 60 ]; then
    err "等待 dpkg 锁超时（10 分钟），请手动检查：ps aux | grep apt"
    exit 1
  fi
  sleep 10
done
log "  dpkg 锁已释放，开始升级"

apt-get update -qq
apt-get upgrade -y -qq -o Dpkg::Options::="--force-confold"
apt-get install -y -qq curl ca-certificates ufw

# ============================================================
# 3) 安装 Docker（官方 get.docker.com 脚本）
# ============================================================
if command -v docker >/dev/null 2>&1; then
  log "[2/3] Docker 已安装：$(docker --version | head -c 60)"
else
  log "[2/3] 安装 Docker（约 1~2 分钟）..."
  if [[ "$MIRROR_MODE" == "cn" ]]; then
    curl -fsSL https://get.docker.com | bash -s -- --mirror Aliyun
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<'EOF'
{"registry-mirrors":["https://docker.m.daocloud.io","https://hub-mirror.c.163.com","https://docker.1ms.run"]}
EOF
    systemctl restart docker
    log "国内镜像加速器已配置"
  else
    curl -fsSL https://get.docker.com | bash
  fi
  systemctl enable --now docker
fi

# ============================================================
# 4) 配置防火墙（ufw 放行 22 / 80 / 443 / 9443）
# ============================================================
log "配置防火墙（ufw）..."
ufw --force reset >/dev/null 2>&1 || true
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp comment 'SSH' >/dev/null
ufw allow 80/tcp comment 'HTTP (Caddy)' >/dev/null
ufw allow 443/tcp comment 'HTTPS (Caddy)' >/dev/null
ufw allow 443/udp comment 'HTTP/3 (Caddy)' >/dev/null
ufw allow 9443/tcp comment 'Portainer Web' >/dev/null
ufw --force enable >/dev/null

# ============================================================
# 5) 创建数据目录
# ============================================================
log "创建数据目录 /opt/bangnicms/data ..."
mkdir -p /opt/bangnicms/data/{postgres,redis,storage,caddy/data,caddy/config,caddy/logs}
# server 容器以 uid=1001 (nodejs) 运行，storage 目录必须可写
chown -R 1001:1001 /opt/bangnicms/data/storage
# redis 容器以 uid=999 运行
chown -R 999:999 /opt/bangnicms/data/redis 2>/dev/null || true

# ============================================================
# 6) 启动 Portainer CE（标准方式，不自动初始化 admin）
# ============================================================
if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
  log "[3/3] Portainer 容器已存在，跳过创建（如需重置：docker rm -f portainer && docker volume rm portainer_data && 重跑本脚本）"
else
  log "[3/3] 启动 Portainer CE..."
  docker volume create portainer_data >/dev/null
  docker run -d \
    --name portainer \
    --restart=unless-stopped \
    -p 9000:9000 \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest >/dev/null
fi

# ============================================================
# 7) 完成提示
# ============================================================
SERVER_IP="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"

cat <<EOF

==============================================================
  🎉  服务器初始化完成！
==============================================================

  Docker      : $(docker --version 2>/dev/null | head -c 60)
  Portainer   : https://${SERVER_IP}:9443
  数据目录    : /opt/bangnicms/data

  下一步操作（5 分钟内必须完成，否则 Portainer 会进入安全锁定）：
  --------------------------------------------------------------
  1) 浏览器打开  https://${SERVER_IP}:9443
     （首次会提示证书不安全，点"高级 → 继续访问"即可）

  2) 设置 admin 用户名 + 密码（请妥善保存）

  3) 登录后选 "Get Started" → "local" 环境

  4) 接下来按部署文档继续：
     https://github.com/miaochi998/bncms-deploy/blob/main/getting-started.md

  ⚠️  云服务商【安全组】也需要放行端口：22 / 80 / 443 / 9443
     • 阿里云：ECS 实例 → 安全组规则
     • 腾讯云：云服务器 → 防火墙
     • 雨云  ：默认全开，无需操作
==============================================================
EOF

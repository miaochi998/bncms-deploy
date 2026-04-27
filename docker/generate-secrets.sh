#!/usr/bin/env bash
# ============================================================
# BangNiCMS 生产密钥生成脚本（PR9）
# ------------------------------------------------------------
# 用法：
#   bash generate-secrets.sh               # 打印到 stdout（预览）
#   bash generate-secrets.sh >> .env.prod  # 追加到 .env.prod
#
# 生成三个 32 字符 URL-safe 随机密钥：
#   - BANGNICMS_POSTGRES_PASSWORD
#   - BANGNICMS_JWT_SECRET
#   - BANGNICMS_REVALIDATE_SECRET
# ============================================================
set -euo pipefail

# 生成 32 字符的 base64 URL-safe 随机字符串
gen_secret() {
  # openssl 输出 24 字节 → base64 32 字符；tr 去掉 URL 不友好字符
  openssl rand -base64 24 | tr -d '=+/' | cut -c1-32
}

cat <<EOF

# === 由 generate-secrets.sh 生成于 $(date -u +"%Y-%m-%dT%H:%M:%SZ") ===
BANGNICMS_POSTGRES_PASSWORD=$(gen_secret)
BANGNICMS_JWT_SECRET=$(gen_secret)
BANGNICMS_REVALIDATE_SECRET=$(gen_secret)
EOF

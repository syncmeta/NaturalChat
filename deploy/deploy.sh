#!/usr/bin/env bash
# deploy.sh — 一键推送代码到 VPS 并重启服务
# 用法: ./deploy/deploy.sh [vps-host]
#   例如: ./deploy/deploy.sh root@1.2.3.4
#   或配置 DEPLOY_HOST 环境变量后直接运行

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEPLOY_HOST="${1:-${DEPLOY_HOST:-}}"
REMOTE_DIR="/opt/naturalchat4"

if [ -z "$DEPLOY_HOST" ]; then
    echo "用法: $0 <user@host>"
    echo "  或设置环境变量 DEPLOY_HOST=user@host"
    exit 1
fi

echo "📦 推送代码到 $DEPLOY_HOST:$REMOTE_DIR ..."
rsync -avz --delete \
    --exclude 'venv/' \
    --exclude '__pycache__/' \
    --exclude '.DS_Store' \
    --exclude 'workspace/' \
    --exclude '.claude/' \
    --exclude 'memobase/' \
    --exclude 'deploy/' \
    --exclude '*.pyc' \
    "$PROJECT_DIR/" "$DEPLOY_HOST:$REMOTE_DIR/"

echo "🔄 远程安装依赖并重启服务..."
ssh "$DEPLOY_HOST" bash -s <<'REMOTE_SCRIPT'
set -euo pipefail
cd /opt/naturalchat4

# 首次部署: 创建 venv
chmod +x deploy/bootstrap-runtime.sh deploy/setup-memobase.sh deploy/render_memobase_config.py
./deploy/bootstrap-runtime.sh /opt/naturalchat4
./venv/bin/python -m ensurepip --upgrade >/dev/null 2>&1 || true
./venv/bin/python -m pip install -q --upgrade pip setuptools wheel
./venv/bin/python -m pip install -q -r requirements.txt

# 配置并启动 Memobase
./deploy/setup-memobase.sh /opt/naturalchat4 /opt/naturalchat4/bots/bot1

# 重启服务
sudo systemctl restart naturalchat4
sleep 1
sudo systemctl status naturalchat4 --no-pager || true
docker compose --env-file /opt/naturalchat4/memobase/.env -f /opt/naturalchat4/deploy/memobase-compose.yml ps || true
echo "✅ 部署完成"
REMOTE_SCRIPT

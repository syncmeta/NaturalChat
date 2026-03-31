#!/bin/bash
# deploy.sh - 推送本地代码到 VPS 并重启 bot
set -euo pipefail

VPS="${VPS_HOST:?请设置 VPS_HOST 环境变量，例如 root@your-server-ip}"
REMOTE_DIR="/opt/naturalchat4"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📦 同步文件..."
rsync -avz --delete \
    --exclude 'venv/' \
    --exclude '__pycache__/' \
    --exclude '.DS_Store' \
    --exclude 'workspace/' \
    --exclude '.claude/' \
    --exclude 'memobase/' \
    --exclude '*.pyc' \
    "$LOCAL_DIR/" "$VPS:$REMOTE_DIR/"

echo "🔄 重启服务..."
ssh "$VPS" 'set -euo pipefail
cd /opt/naturalchat4
chmod +x deploy/bootstrap-runtime.sh deploy/setup-memobase.sh deploy/render_memobase_config.py
./deploy/bootstrap-runtime.sh /opt/naturalchat4
./venv/bin/python -m ensurepip --upgrade >/dev/null 2>&1 || true
./venv/bin/python -m pip install -q --upgrade pip setuptools wheel
./venv/bin/python -m pip install -q -r requirements.txt
./deploy/setup-memobase.sh /opt/naturalchat4 /opt/naturalchat4/bots/bot1
systemctl restart naturalchat4
sleep 2
journalctl -u naturalchat4 -n 10 --no-pager
docker compose --env-file /opt/naturalchat4/memobase/.env -f /opt/naturalchat4/deploy/memobase-compose.yml ps || true'

echo "✅ 部署完成"

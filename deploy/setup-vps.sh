#!/usr/bin/env bash
# setup-vps.sh — VPS 首次初始化 (只需运行一次)
# 用法: ssh root@your-vps 'bash -s' < deploy/setup-vps.sh

set -euo pipefail

echo "📋 安装系统依赖..."
apt-get update -qq
apt-get install -y -qq python3 python3-venv python3-pip rsync > /dev/null

echo "📁 创建项目目录..."
mkdir -p /opt/naturalchat4

echo "⚙️ 安装 systemd 服务..."
cat > /etc/systemd/system/naturalchat4.service <<'EOF'
[Unit]
Description=NaturalChat4 Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/naturalchat4
ExecStart=/opt/naturalchat4/venv/bin/python3 main.py
Restart=on-failure
RestartSec=5
MemoryMax=512M
Environment=PYTHONUNBUFFERED=1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable naturalchat4

echo ""
echo "✅ VPS 初始化完成！"
echo "   接下来在本地运行: ./deploy/deploy.sh root@$(hostname -I | awk '{print $1}')"

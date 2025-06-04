#!/bin/bash

# Comprehensive setup script for Nachna API on Amazon Linux 2
# This script sets up NGINX, SSL, network optimizations, and systemd service

set -e  # Exit on error

echo "=== Nachna API Setup for Amazon Linux 2 ==="
echo "This script will:"
echo "1. Install and configure NGINX with SSL/TLS"
echo "2. Optimize network performance"
echo "3. Set up the FastAPI service"
echo "4. Configure security settings"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Get user email for SSL certificate
read -p "Enter your email for SSL certificate: " USER_EMAIL

# Step 1: System Update
echo "=== Step 1: Updating system ==="
sudo yum update -y

# Step 2: Install required packages
echo "=== Step 2: Installing required packages ==="
sudo yum install -y python3 python3-pip python3-devel gcc
sudo yum install -y htop iotop sysstat git
sudo amazon-linux-extras install epel -y
sudo amazon-linux-extras install nginx1 -y
sudo yum install -y iftop nethogs

# Step 3: Set up Python virtual environment
echo "=== Step 3: Setting up Python virtual environment ==="
cd /home/ec2-user/Dance
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Step 4: Configure NGINX
echo "=== Step 4: Configuring NGINX ==="
sudo tee /etc/nginx/conf.d/nachna.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name nachna.com www.nachna.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name nachna.com www.nachna.com;
    
    # SSL configuration will be added by certbot
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml application/atom+xml image/svg+xml;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Proxy settings
    location / {
        proxy_pass http://127.0.0.1:8002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # Static file caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

sudo rm -f /etc/nginx/conf.d/default.conf
sudo nginx -t
sudo systemctl start nginx
sudo systemctl enable nginx

# Step 5: Install and configure SSL certificate
echo "=== Step 5: Setting up SSL certificate ==="
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot
sudo certbot --nginx -d nachna.com -d www.nachna.com --non-interactive --agree-tos --email $USER_EMAIL

# Set up automatic renewal
echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/bin/certbot renew -q" | sudo tee -a /etc/crontab > /dev/null

# Step 6: Network optimizations
echo "=== Step 6: Applying network optimizations ==="
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Network Performance Tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_budget = 600
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.netfilter.nf_conntrack_max = 131072
net.ipv4.tcp_max_syn_backlog = 3240000
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
EOF

sudo sysctl -p
sudo modprobe tcp_bbr
echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/modules.conf

# Step 7: Set up systemd service
echo "=== Step 7: Setting up systemd service ==="
sudo cp nachna-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable nachna-api
sudo systemctl start nachna-api

# Step 8: Configure firewall
echo "=== Step 8: Configuring firewall ==="
sudo iptables -F INPUT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p icmp -j ACCEPT
sudo iptables -A INPUT -j DROP
sudo service iptables save

# Step 9: Install monitoring tools
echo "=== Step 9: Installing monitoring tools ==="
chmod +x diagnose_latency.sh monitor_performance.py

# Step 10: Final checks
echo "=== Step 10: Running final checks ==="
echo "Checking NGINX status:"
sudo systemctl status nginx --no-pager

echo ""
echo "Checking FastAPI service status:"
sudo systemctl status nachna-api --no-pager

echo ""
echo "Testing API endpoint:"
curl -s -o /dev/null -w "Response time: %{time_total}s\n" https://nachna.com/api/workshops?version=v2

echo ""
echo "=== Setup Complete! ==="
echo "Your API should now be accessible at https://nachna.com"
echo ""
echo "Important notes:"
echo "1. Make sure EC2 security group allows ports 80 and 443"
echo "2. Update your Flutter app to use https://nachna.com"
echo "3. Monitor logs with: sudo journalctl -u nachna-api -f"
echo "4. Check NGINX logs at: /var/log/nginx/"
echo ""
echo "To diagnose performance issues, run:"
echo "  ./diagnose_latency.sh"
echo "  python3 monitor_performance.py"


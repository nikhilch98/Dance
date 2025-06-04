#!/bin/bash

# Setup NGINX with SSL/TLS for FastAPI server on Amazon Linux 2
# This script configures NGINX as a reverse proxy with HTTPS

echo "Setting up NGINX with SSL/TLS for nachna.com on Amazon Linux 2"

# Update system
sudo yum update -y

# Install NGINX
sudo amazon-linux-extras install nginx1 -y

# Install certbot for SSL certificates
sudo yum install -y python3 augeas-libs
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# Create NGINX configuration
sudo tee /etc/nginx/conf.d/nachna.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name nachna.com www.nachna.com;
    
    # Redirect all HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name nachna.com www.nachna.com;
    
    # SSL configuration will be added by certbot
    
    # Enable gzip compression at NGINX level
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

# Remove default NGINX configuration if exists
sudo rm -f /etc/nginx/conf.d/default.conf

# Test NGINX configuration
sudo nginx -t

# Start and enable NGINX
sudo systemctl start nginx
sudo systemctl enable nginx

# Obtain SSL certificate
echo "Obtaining SSL certificate from Let's Encrypt..."
echo "Please replace 'your-email@example.com' with your actual email address"
sudo certbot --nginx -d nachna.com -d www.nachna.com --non-interactive --agree-tos --email your-email@example.com

# Set up automatic renewal
echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/bin/certbot renew -q" | sudo tee -a /etc/crontab > /dev/null

echo "NGINX with SSL/TLS setup complete!"
echo "Don't forget to:"
echo "1. Update your FastAPI server to run on port 8002"
echo "2. Configure your EC2 security group to allow ports 80 and 443"
echo "3. Update your app to use https://nachna.com instead of http://" 
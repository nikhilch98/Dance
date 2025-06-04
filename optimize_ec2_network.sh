#!/bin/bash

echo "=== Optimizing EC2 Network Performance on Amazon Linux 2 ==="

# 1. Update system
sudo yum update -y

# 2. Install performance tools
sudo yum install -y htop iotop sysstat
# nethogs and iftop need EPEL repository
sudo amazon-linux-extras install epel -y
sudo yum install -y iftop nethogs

# 3. Optimize kernel parameters for network performance
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Network Performance Tuning
# Increase TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Increase netdev budget
net.core.netdev_budget = 600
net.core.netdev_max_backlog = 5000

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Optimize TCP settings
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1

# Connection tracking
net.netfilter.nf_conntrack_max = 131072
net.ipv4.tcp_max_syn_backlog = 3240000

# Enable TCP keepalive
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# Reuse TIME_WAIT sockets
net.ipv4.tcp_tw_reuse = 1

# Increase ephemeral port range
net.ipv4.ip_local_port_range = 1024 65535
EOF

# Apply sysctl settings
sudo sysctl -p

# 4. Enable BBR congestion control
sudo modprobe tcp_bbr
echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/modules.conf

# 5. Optimize network interface
# Get primary network interface
INTERFACE=$(ip route | grep default | awk '{print $5}')

# Increase ring buffer sizes
sudo ethtool -G $INTERFACE rx 4096 tx 4096 2>/dev/null || echo "Could not change ring buffer size"

# Enable offloading features
sudo ethtool -K $INTERFACE rx on tx on sg on tso on gso on gro on lro on 2>/dev/null || echo "Some offloading features not supported"

# 6. Configure iptables (Amazon Linux 2 doesn't use UFW)
# Allow necessary ports
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8002 -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT

# Save iptables rules
sudo service iptables save

# 7. Install and configure fail2ban for security
sudo yum install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# 8. Configure fail2ban for SSH protection
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

sudo systemctl restart fail2ban

echo "=== Network optimization complete ==="
echo "Please reboot the server for all changes to take effect" 
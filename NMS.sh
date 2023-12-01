#!/bin/bash

# Function to configure a target machine
configure_target() {
  local target_ip=$1
  local hostname=$2

  # Establish SSH connection
  ssh remoteadmin@$target_ip "
    # Set system hostname
    sudo hostnamectl set-hostname $hostname
    sudo sed -i 's/^127.0.1.1.*/127.0.1.1\t$hostname/g' /etc/hosts

    # Update IP address
    sudo ip addr del 172.16.1.$((10#$hostname % 255)) dev eth0
    sudo ip addr add 172.16.1.$((10#$hostname % 255)) dev eth0

    # Update /etc/hosts with webhost
    echo '172.16.1.4 webhost' | sudo tee -a /etc/hosts

    # Install and configure ufw
    sudo apt-get update
    sudo apt-get install -y ufw
    sudo ufw allow from 172.16.1.0/24 to any port 514/udp
    sudo ufw --force enable

    # Configure rsyslog for UDP
    sudo sed -i '/^#module(imudp)/s/^#//;/^#input(imudp/s/^#//;/^#imudp/s/^#//' /etc/rsyslog.conf
    sudo systemctl restart rsyslog
  "
}

# Configure machines
configure_target 172.16.1.10 loghost
configure_target 172.16.1.11 webhost

# Update NMS /etc/hosts file
echo "172.16.1.10 loghost" | sudo tee -a /etc/hosts
echo "172.16.1.11 webhost" | sudo tee -a /etc/hosts

# Check Apache response
if curl -s http://webhost; then
  echo "Configuration update succeeded. Apache responded properly."
else
  echo "Configuration update failed. Unable to retrieve Apache response."
fi

# Verify syslog entries on loghost
if ssh remoteadmin@loghost grep webhost /var/log/syslog; then
  echo "Syslog entries show logs from webhost."
else
  echo "Syslog entries do not show logs from webhost."
fi


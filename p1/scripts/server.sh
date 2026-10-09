#!/bin/bash

set -euo pipefail

SERVER_IP="$1"
TOKEN_FILE="/vagrant/.k3s-token"

# The private network interface name depends on the box (eth1, enp0s8, ...),
# so look it up from its IP instead of hardcoding it.
IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ "^" ip "/" {print $2}')

# Drop a token left over from a previous cluster
rm -f "$TOKEN_FILE"

apt-get update
apt-get install -y curl

curl -sfL https://get.k3s.io | \
  K3S_KUBECONFIG_MODE="644" \
  INSTALL_K3S_EXEC="server --node-ip=$SERVER_IP --flannel-iface=$IFACE" \
  sh -

until systemctl is-active --quiet k3s; do
    sleep 2
done

until [ -s /var/lib/rancher/k3s/server/node-token ]; do
    sleep 2
done

# Share the join token with the worker through the synced folder
cp /var/lib/rancher/k3s/server/node-token "$TOKEN_FILE"
chmod 644 "$TOKEN_FILE"

grep -q "alias k=" /home/vagrant/.bashrc || echo "alias k='kubectl'" >> /home/vagrant/.bashrc

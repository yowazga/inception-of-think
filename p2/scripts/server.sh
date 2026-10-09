#!/bin/bash

set -euo pipefail

SERVER_IP="$1"

# The private network interface name depends on the box (eth1, enp0s8, ...)
IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ "^" ip "/" {print $2}')

apt-get update
apt-get install -y curl

curl -sfL https://get.k3s.io | \
  K3S_KUBECONFIG_MODE="644" \
  INSTALL_K3S_EXEC="server --node-ip=$SERVER_IP --flannel-iface=$IFACE" \
  sh -

# Wait for the K3s node to be Ready (a plain grep "Ready" also matches "NotReady")
until kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -qx "Ready"; do
  sleep 2
done

# Apply configuration files
kubectl apply -f /vagrant/confs/

kubectl wait --for=condition=available deployment --all --timeout=300s

grep -q "alias k=" /home/vagrant/.bashrc || echo "alias k='kubectl'" >> /home/vagrant/.bashrc

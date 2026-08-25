#!/bin/bash

set -e

apt-get update
apt-get install -y curl

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-iface=enp0s8" sh -s -

# Wait for the K3s node to be ready
until kubectl get nodes | grep -q "Ready"; do
  sleep 2
done
# Apply configuration files
kubectl apply -f /vagrant/confs/
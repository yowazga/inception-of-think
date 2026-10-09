#!/bin/bash

set -euo pipefail

SERVER_IP="$1"
WORKER_IP="$2"
TOKEN_FILE="/vagrant/.k3s-token"

IFACE=$(ip -o -4 addr show | awk -v ip="$WORKER_IP" '$4 ~ "^" ip "/" {print $2}')

apt-get update
apt-get install -y curl

# The server writes its join token once K3s is up (5 min max)
for _ in $(seq 150); do
    [ -s "$TOKEN_FILE" ] && break
    sleep 2
done

if [ ! -s "$TOKEN_FILE" ]; then
    echo "K3s token not found in $TOKEN_FILE: is the server up?" >&2
    exit 1
fi

curl -sfL https://get.k3s.io | \
  K3S_URL="https://$SERVER_IP:6443" \
  K3S_TOKEN="$(cat "$TOKEN_FILE")" \
  INSTALL_K3S_EXEC="agent --node-ip=$WORKER_IP --flannel-iface=$IFACE" \
  sh -

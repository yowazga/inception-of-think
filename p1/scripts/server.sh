#!/bin/bash

set -e

apt-get update
apt-get install -y curl

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s -

until systemctl is-active --quiet k3s; do
    sleep 2
done

TOKEN_FILE="/vagrant/.k3s-token"

sudo cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"

chmod 644 "$TOKEN_FILE"
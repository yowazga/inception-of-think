#!/bin/bash

set -e

apt-get update
apt-get install -y curl

while [ ! -f /vagrant/.k3s-token ]; do
    sleep 2
done

TOKEN=$(cat /vagrant/.k3s-token)

curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.56.110:6443" \
  K3S_TOKEN="$TOKEN" \
  sh -
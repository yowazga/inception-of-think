#!/bin/bash

set -e

apt-get update
apt-get install -y curl

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s -
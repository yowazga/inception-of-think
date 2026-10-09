#!/bin/bash

set -e

# ubuntu or debian: both have an official Docker apt repository
DISTRO="$(. /etc/os-release && echo "$ID")"

echo "==> Updating system packages"
sudo apt-get update

echo "==> Installing required packages"
sudo apt-get install -y \
    ca-certificates \
    curl \
    git \
    gnupg

echo "==> Installing Docker"
if ! command -v docker >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL \
        "https://download.docker.com/linux/${DISTRO}/gpg" \
        -o /etc/apt/keyrings/docker.asc

    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "Types: deb
URIs: https://download.docker.com/linux/${DISTRO}
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc" | \
      sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null

    sudo apt-get update

    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
fi

echo "==> Configuring Docker access"
if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    echo "Docker group added. Log out and back in before using docker without sudo."
fi

echo "==> Installing k3d"
if ! command -v k3d >/dev/null 2>&1; then
   curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

echo "==> Installing kubectl"
if ! command -v kubectl >/dev/null 2>&1; then
    KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

    curl -LO \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/$(dpkg --print-architecture)/kubectl"

    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    rm kubectl
fi

echo "==> Verifying installation"

docker --version
k3d version
kubectl version --client

echo "==> Installation complete"

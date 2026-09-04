#!/bin/bash

set -e

CLUSTER_NAME="iot"

echo "==> Checking k3d"
if ! command -v k3d >/dev/null 2>&1; then
    echo "k3d is not installed."
    exit 1
fi

echo "==> Checking Docker"
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not available."
    exit 1
fi

echo "==> Checking existing cluster"
if k3d cluster get "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "Cluster '$CLUSTER_NAME' already exists."
    exit 0
fi

echo "==> Creating k3d cluster: $CLUSTER_NAME"
k3d cluster create "$CLUSTER_NAME"

echo "==> Cluster created"

kubectl get nodes
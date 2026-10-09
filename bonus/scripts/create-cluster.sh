#!/bin/bash

set -e

CLUSTER_NAME="bonus"

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

# The Part 3 cluster also listens on port 8888: stop it (k3d cluster start iot
# brings it back)
if k3d cluster get iot >/dev/null 2>&1; then
    echo "==> Stopping the Part 3 cluster to free port 8888"
    k3d cluster stop iot
fi

echo "==> Checking existing cluster"
if k3d cluster get "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "Cluster '$CLUSTER_NAME' already exists, making sure it is running."
    k3d cluster start "$CLUSTER_NAME"
    kubectl config use-context "k3d-$CLUSTER_NAME"
    exit 0
fi

echo "==> Creating k3d cluster: $CLUSTER_NAME"
# Both host ports go to Traefik: port 80 serves GitLab (gitlab.localhost),
# port 8888 serves the app, as in Part 3
k3d cluster create "$CLUSTER_NAME" \
    --port "80:80@loadbalancer" \
    --port "8888:80@loadbalancer" \
    --wait

echo "==> Cluster created"

kubectl get nodes

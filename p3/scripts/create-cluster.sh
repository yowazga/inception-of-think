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
    echo "Cluster '$CLUSTER_NAME' already exists, making sure it is running."
    k3d cluster start "$CLUSTER_NAME"
    kubectl config use-context "k3d-$CLUSTER_NAME"
    exit 0
fi

echo "==> Creating k3d cluster: $CLUSTER_NAME"
# Host port 8888 goes to Traefik (the K3s ingress controller), which routes
# to the app through confs/app-ingress.yaml: localhost:8888 keeps working
# when Argo CD replaces the pod with a new version.
k3d cluster create "$CLUSTER_NAME" \
    --port "8888:80@loadbalancer" \
    --wait

echo "==> Cluster created"

kubectl get nodes

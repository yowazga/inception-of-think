#!/bin/bash

set -e

CLUSTER_NAME="iot"
CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null

echo "==> Creating namespaces"
kubectl apply -f "$CONFS/argocd-namespace.yaml" -f "$CONFS/dev-namespace.yaml"

echo "==> Installing Argo CD"
# Server-side apply: the Argo CD CRDs are too big for a client-side apply
kubectl apply -n argocd --server-side --force-conflicts -f "$ARGOCD_MANIFEST"

# Poll Git every 30s instead of every ~3 min, so a pushed version shows up quickly
kubectl -n argocd patch configmap argocd-cm --type merge \
    -p '{"data":{"timeout.reconciliation":"30s"}}'
kubectl -n argocd rollout restart \
    statefulset/argocd-application-controller deployment/argocd-repo-server

echo "==> Waiting for Argo CD"
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s
kubectl -n argocd wait --for=condition=available deployment --all --timeout=600s

echo "==> Deploying the application"
kubectl apply -f "$CONFS/app-ingress.yaml"
kubectl apply -f "$CONFS/application.yaml"

echo "==> Waiting for Argo CD to sync the dev namespace"
for _ in $(seq 60); do
    kubectl -n dev get deployment playground >/dev/null 2>&1 && break
    sleep 5
done
kubectl -n dev rollout status deployment/playground --timeout=300s

PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d)

cat <<EOF

==> Done
  App:        curl http://localhost:8888/
  Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443
              then open https://localhost:8080
              user: admin  password: $PASSWORD
EOF

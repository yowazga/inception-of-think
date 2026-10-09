#!/bin/bash

set -e

CLUSTER_NAME="bonus"
CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"
GITLAB_HOST="gitlab.localhost"

kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null

echo "==> Creating gitlab namespace"
kubectl apply -f "$CONFS/gitlab-namespace.yaml"

echo "==> Creating GitLab root password"
# Keep an existing one: GitLab only reads it when it creates its database
if ! kubectl -n gitlab get secret gitlab-root-password >/dev/null 2>&1; then
    kubectl -n gitlab create secret generic gitlab-root-password \
        --from-literal=password="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"
fi

echo "==> Deploying GitLab"
kubectl apply -f "$CONFS/gitlab.yaml"

echo "==> Waiting for GitLab (the first boot takes 5 to 10 minutes)"
kubectl -n gitlab rollout status deployment/gitlab --timeout=1800s

# *.localhost names usually resolve to 127.0.0.1 already, but not with every resolver
if ! getent hosts "$GITLAB_HOST" >/dev/null; then
    echo "==> Adding $GITLAB_HOST to /etc/hosts"
    echo "127.0.0.1 $GITLAB_HOST" | sudo tee -a /etc/hosts >/dev/null
fi

echo "==> Waiting for http://$GITLAB_HOST"
for _ in $(seq 60); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "http://$GITLAB_HOST/users/sign_in")" = "200" ] && break
    sleep 5
done

VERSION=$(kubectl -n gitlab exec deploy/gitlab -- head -n 1 /opt/gitlab/version-manifest.txt \
    2>/dev/null || echo "version unknown")
PASSWORD=$(kubectl -n gitlab get secret gitlab-root-password \
    -o jsonpath='{.data.password}' | base64 -d)

cat <<EOF

==> GitLab is up ($VERSION)
  URL: http://$GITLAB_HOST
  user: root  password: $PASSWORD
EOF

#!/bin/bash

# Put the app manifests (confs/app) in a new GitLab project: root/yowazga-iot-app

set -e

CLUSTER_NAME="bonus"
CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"
PROJECT="root/yowazga-iot-app"
APP_DIR="$HOME/gitlab-yowazga-iot-app"

kubectl config use-context "k3d-$CLUSTER_NAME" >/dev/null

PASSWORD=$(kubectl -n gitlab get secret gitlab-root-password \
    -o jsonpath='{.data.password}' | base64 -d)
REMOTE="http://root:$PASSWORD@gitlab.localhost/$PROJECT.git"

echo "==> Preparing the app repository in $APP_DIR"
if [ ! -d "$APP_DIR/.git" ]; then
    mkdir -p "$APP_DIR"
    cp "$CONFS"/app/*.yaml "$APP_DIR/"
    git -C "$APP_DIR" init -q -b main
    git -C "$APP_DIR" config user.name "yowazga"
    git -C "$APP_DIR" config user.email "yowazga@gitlab.localhost"
    git -C "$APP_DIR" add .
    git -C "$APP_DIR" commit -q -m "feat: deploy playground v1"
fi

# The password changes when GitLab is reinstalled: always refresh the remote
if git -C "$APP_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$APP_DIR" remote set-url origin "$REMOTE"
else
    git -C "$APP_DIR" remote add origin "$REMOTE"
fi

echo "==> Pushing to GitLab"
# Pushing to a project that does not exist yet makes GitLab create it (private)
git -C "$APP_DIR" push -u origin main

echo "==> Project: http://gitlab.localhost/$PROJECT"

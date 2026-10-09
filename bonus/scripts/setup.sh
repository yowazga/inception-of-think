#!/bin/bash

# Whole bonus: tools, k3d cluster, GitLab, and Argo CD deploying the app from GitLab
# Needs about 8 GB of RAM: GitLab alone uses 3 to 4 GB

set -e

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"

bash "$SCRIPTS/install.sh"

# Right after install.sh adds us to the docker group, this shell does not
# have it yet: run the k3d part through sg instead of asking for a re-login
if docker info >/dev/null 2>&1; then
    bash "$SCRIPTS/create-cluster.sh"
else
    sg docker -c "bash '$SCRIPTS/create-cluster.sh'"
fi

bash "$SCRIPTS/setup-gitlab.sh"
bash "$SCRIPTS/push-app.sh"
bash "$SCRIPTS/setup-argocd.sh"

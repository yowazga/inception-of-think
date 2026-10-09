#!/bin/bash

# Whole Part 3: tools, k3d cluster, Argo CD and the app deployed from GitHub

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

bash "$SCRIPTS/setup-argocd.sh"

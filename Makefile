# Inception-of-Things: run every part from the repository root, inside the Linux VM
# "make" alone lists the targets

SHELL := /bin/bash
.DEFAULT_GOAL := help

LOGIN          := yowazga
SERVER_IP      := 192.168.56.110
P3_CTX         := k3d-iot
BONUS_CTX      := k3d-bonus
APP_REPO       ?= git@github.com:yowazga/yowazga-iot-app.git
APP_DIR        ?= $(HOME)/yowazga-iot-app
GITLAB_APP_DIR ?= $(HOME)/gitlab-yowazga-iot-app
V              ?= v2

.PHONY: help deps all clean \
	p1 p1-check p1-down \
	p2 p2-check p2-down \
	p3 p3-check p3-version p3-password p3-ui p3-down \
	bonus bonus-check bonus-version bonus-password bonus-ui bonus-down

help: ## Show this list
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

deps: ## Install git, curl, VirtualBox and Vagrant in the VM (needed for p1 and p2)
	sudo apt-get update
	sudo apt-get install -y git curl virtualbox
	@if ! command -v vagrant >/dev/null; then \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp.gpg; \
		codename=$$(. /etc/os-release && echo "$$VERSION_CODENAME"); \
		curl -sfI "https://apt.releases.hashicorp.com/dists/$$codename/Release" >/dev/null || codename=noble; \
		echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $$codename main" | \
			sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null; \
		sudo apt-get update && sudo apt-get install -y vagrant; \
	fi
	@vagrant --version
	@VBoxManage --version
	@echo "CPU virtualization flags: $$(grep -cE 'vmx|svm' /proc/cpuinfo) (must be more than 0 for p1 and p2)"

all: ## Run every part in order with its checks (about 30 min)
	$(MAKE) p1 p1-check
	$(MAKE) p2 p2-check p2-down
	$(MAKE) p3 p3-check
	$(MAKE) bonus bonus-check

clean: ## Destroy every VM and k3d cluster
	-cd p1 && vagrant destroy -f
	-cd p2 && vagrant destroy -f
	-k3d cluster delete iot
	-k3d cluster delete bonus

# ---------------------------------------------------------------- Part 1

p1: ## Part 1: start yowazgaS (server) and yowazgaSW (agent)
	cd p1 && vagrant up

p1-check: ## Part 1: show both nodes and their private IPs
	cd p1 && vagrant ssh $(LOGIN)S -c "kubectl get nodes -o wide; ip -4 -br a"
	cd p1 && vagrant ssh $(LOGIN)SW -c "ip -4 -br a"

p1-down: ## Part 1: destroy both VMs
	cd p1 && vagrant destroy -f

# ---------------------------------------------------------------- Part 2

p2: p1-down ## Part 2: start yowazgaS with the 3 apps (destroys Part 1: same name and IP)
	cd p2 && vagrant up

p2-check: ## Part 2: query app1.com, app2.com (3 times) and the default app3
	curl -s -H "Host: app1.com" $(SERVER_IP) | grep -E "h1|pod"
	for i in 1 2 3; do curl -s -H "Host: app2.com" $(SERVER_IP) | grep -E "h1|pod"; done
	curl -s $(SERVER_IP) | grep -E "h1|pod"
	cd p2 && vagrant ssh $(LOGIN)S -c "kubectl get all,ingress"

p2-down: ## Part 2: destroy the VM
	cd p2 && vagrant destroy -f

# ---------------------------------------------------------------- Part 3

p3: ## Part 3: install the tools, create the k3d cluster, install Argo CD and the app
	bash p3/scripts/setup.sh

p3-check: ## Part 3: namespaces, dev pod and the app answer on port 8888
	kubectl --context $(P3_CTX) get ns
	kubectl --context $(P3_CTX) get pods -n dev
	curl -s http://localhost:8888/; echo

p3-version: ## Part 3: set the app version on GitHub (make p3-version V=v1 or V=v2)
	@[ -d "$(APP_DIR)/.git" ] || git clone $(APP_REPO) "$(APP_DIR)"
	cd "$(APP_DIR)" && git pull -q && \
		sed -i -E 's#(wil42/playground:)v[0-9]+#\1$(V)#' deployment.yaml && \
		grep "image:" deployment.yaml && \
		if git diff --quiet; then echo "Already on $(V)"; \
		else git commit -qam "playground $(V)" && git push; fi
	@echo "Argo CD checks the repository every 30 s, then run: make p3-check"

p3-password: ## Part 3: print the Argo CD admin password
	@kubectl --context $(P3_CTX) -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d; echo

p3-ui: p3-password ## Part 3: open the Argo CD UI on https://localhost:8080 (Ctrl+C to stop)
	kubectl --context $(P3_CTX) port-forward svc/argocd-server -n argocd 8080:443

p3-down: ## Part 3: delete the k3d cluster
	bash p3/scripts/delete-cluster.sh

# ---------------------------------------------------------------- Bonus

bonus: ## Bonus: GitLab + Argo CD + the app from GitLab (stops the Part 3 cluster)
	bash bonus/scripts/setup.sh

bonus-check: ## Bonus: namespaces, GitLab and dev pods, the app answer on port 8888
	kubectl --context $(BONUS_CTX) get ns
	kubectl --context $(BONUS_CTX) get pods -n gitlab
	kubectl --context $(BONUS_CTX) get pods -n dev
	curl -s http://localhost:8888/; echo

bonus-version: ## Bonus: set the app version on GitLab (make bonus-version V=v1 or V=v2)
	cd "$(GITLAB_APP_DIR)" && \
		sed -i -E 's#(wil42/playground:)v[0-9]+#\1$(V)#' deployment.yaml && \
		grep "image:" deployment.yaml && \
		if git diff --quiet; then echo "Already on $(V)"; \
		else git commit -qam "playground $(V)" && git push; fi
	@echo "Argo CD checks the repository every 30 s, then run: make bonus-check"

bonus-password: ## Bonus: print the GitLab root and Argo CD admin passwords
	@echo -n "GitLab  (root):  "; kubectl --context $(BONUS_CTX) -n gitlab get secret gitlab-root-password \
		-o jsonpath='{.data.password}' | base64 -d; echo
	@echo -n "Argo CD (admin): "; kubectl --context $(BONUS_CTX) -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d; echo

bonus-ui: bonus-password ## Bonus: open the Argo CD UI on https://localhost:8080 (GitLab: http://gitlab.localhost)
	kubectl --context $(BONUS_CTX) port-forward svc/argocd-server -n argocd 8080:443

bonus-down: ## Bonus: delete the k3d cluster
	bash bonus/scripts/delete-cluster.sh

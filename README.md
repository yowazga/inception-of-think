# Inception-of-Things

Login used for machine and repository names: `yowazga`.

| Part | Content | Run |
|---|---|---|
| p1 | K3s server `yowazgaS` (192.168.56.110) and agent `yowazgaSW` (192.168.56.111) with Vagrant | `cd p1 && vagrant up` |
| p2 | K3s server running 3 apps behind the Traefik ingress | `cd p2 && vagrant up` |
| p3 | k3d + Argo CD deploying `wil42/playground` from GitHub | `bash p3/scripts/setup.sh` |
| bonus | Part 3 with a local GitLab as the Git source | `bash bonus/scripts/setup.sh` |

## With make

Everything runs inside the Linux VM, from the repository root. Run `make` alone to list all targets.

```sh
sudo apt-get install -y make    # Ubuntu Desktop does not ship it
make deps                       # git, curl, VirtualBox, Vagrant (for p1 and p2)

make p1 && make p1-check        # Part 1
make p2 && make p2-check        # Part 2 (destroys Part 1 first)
make p2-down

make p3 && make p3-check        # Part 3
make p3-version V=v2            # push v2 to GitHub, wait 30 s, then make p3-check
make p3-ui                      # Argo CD UI on https://localhost:8080

make bonus && make bonus-check  # Bonus
make bonus-version V=v2         # push v2 to GitLab, wait 30 s, then make bonus-check
make bonus-ui

make clean                      # destroy every VM and cluster
```

## Part 1

```sh
vagrant ssh yowazgaS -c "kubectl get nodes -o wide"
vagrant ssh yowazgaSW -c "ip a"
```

## Part 2

```sh
curl -H "Host: app1.com" 192.168.56.110   # app1
curl -H "Host: app2.com" 192.168.56.110   # app2: run it a few times, the pod name changes (3 replicas)
curl 192.168.56.110                       # app3 (default)
vagrant ssh yowazgaS -c "kubectl get all,ingress"
```

## Part 3

`setup.sh` runs `install.sh` (Docker, k3d, kubectl), `create-cluster.sh` and `setup-argocd.sh`.
The app comes from <https://github.com/yowazga/yowazga-iot-app>.

```sh
kubectl get ns
kubectl get pods -n dev
curl http://localhost:8888/

# in a clone of yowazga-iot-app
sed -i 's/playground:v1/playground:v2/' deployment.yaml
git commit -am "v2" && git push

# Argo CD polls the repository every 30 s
curl http://localhost:8888/
```

Argo CD UI: `kubectl port-forward svc/argocd-server -n argocd 8080:443`, then <https://localhost:8080>
(user `admin`, password printed at the end of the setup).

## Bonus

Needs about 8 GB of RAM. The setup stops the Part 3 cluster, which also uses port 8888
(`k3d cluster start iot` brings it back).

GitLab runs from the official `gitlab/gitlab-ce:latest` image in the `gitlab` namespace, at
<http://gitlab.localhost> (user `root`, password printed by the setup). The GitLab Helm chart
(10.x) no longer ships PostgreSQL and Redis, while this image includes them.

The app manifests (`bonus/confs/app`) are pushed to the private project `root/yowazga-iot-app`.
Argo CD pulls it through the in-cluster service `gitlab.gitlab.svc.cluster.local`.

```sh
kubectl get ns
kubectl get pods -n gitlab
kubectl get pods -n dev
curl http://localhost:8888/

cd ~/gitlab-yowazga-iot-app
sed -i 's/playground:v1/playground:v2/' deployment.yaml
git commit -am "v2" && git push

curl http://localhost:8888/
```

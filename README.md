# Homelab Infrastructure

> Provisioning a single-node Kubernetes cluster with kubeadm/k3s, Ansible and Terraform

## What is this project about?

This project aims to provision a single-node Kubernetes cluster on a Ubuntu server and consists of two stages:

- Stage 1: Ansible
  - Install fail2ban, disable multipathd, setup ufw and other tasks.
  - Provision a single-node Kubernetes cluster using k3s or kubeadm.
    - Main method to bootstrap the cluster: **kubeadm** <https://kubernetes.io/docs/reference/setup-tools/kubeadm/>
    - Alternative method: **k3s** Repository: <https://github.com/k3s-io/k3s-ansible>

- Stage 2: Terraform
  - Nginx
  - Cert manager
  - Longhorn
  - Minio
  - Gitlab
  - Prometheus/Grafana/AlertManager
  - Elasticsearch/Kibana/Filebeat (Elastic Cloud on Kubernetes)
  - ElastAlert2
  - Kubecost (<https://www.kubecost.com/>)
  - Tailscale (<https://tailscale.com/>)
  - Wireguard
  - ArgoCD

The docker image contains the following tools:

- kubectl
- helm
- terraform
- ansible
- kubent

## Prerequisite

1. Set up Terraform Cloud and create an API key.

2. Install Ubuntu AMD64 on a server and configure the following:
   - Gitlab (`registry.gitlab.com/gitlab-org/build/cng/kubectl`) does not support ARM64 yet.
   - Note that the server SSH port must not be `22`.

     ```shell
     $ ssh chrislee@192.168.1.100

     >$ sudo mkdir -p /etc/systemd/system/ssh.socket.d
     >$ sudo cat >/etc/systemd/system/ssh.socket.d/override.conf <<EOF
     [Socket]
     ListenStream=2222
     EOF

     >$ sudo systemctl daemon-reload
     >$ reboot

     $ ssh chrislee@192.168.1.1000 -p2222

     >$ vim ~/.ssh/authorized_keys
     Add the public key located at ~/.ssh/id_rsa.pub to the authorized_keys file for the root user on Ubuntu.
     ```

## Steps

### Stage 0: Setup the environment

1. Copy the .env.sample file to a new file named .env and configure it accordingly.

   ```bash
   cp .env.sample .env
   ```

   - Make sure to set `kubernetes_cluster_type` to either `k3s` or `kubeadm`.
   - Note that `minikube` can be provisioned but failed to work with the current setup.

2. Ensure that you have an SSH key file ready for use with Ubuntu (e.g., ~/.ssh/id_rsa.pub).

3. Run `repo:setup` to make sure you have all the necessary tools.

      ```bash
      npm run repo:setup
      ```

### Stage 1: Provision Kubernetes Cluster

1. Verify access by running the following commands:

    ```bash
    $ npm run docker:exec
    /srv# cd stage1
    /srv/stage1# ansible all -i "inventories/inventory.yml" -m ping
    ```

2. Prepare the VM template by running the following command:

    ```bash
    /srv/stage1# ansible-playbook --ask-become-pass -i "inventories/inventory.yml" site.yml
    BECOME password: <ubuntu root password>
    ```

    - At the end of the playbook, the `.kube/config` should be copied to the local machine in `container/root/.kube/config`.

### Stage 2: Deploy Kubernetes Infrastructure

1. Initialize Terraform by running the following commands:

    ```bash
    $ npm run docker:exec
    /srv# cd stage2
    /srv/stage2# terraform workspace select <workspace name>
    /srv/stage2# terraform init
    ```

2. Provision VM nodes using Terraform by running the following commands:

    ```bash
    /srv/stage2# terraform plan
    /srv/stage2# terraform apply
    ```

## Troubleshooting

### Running `pre-commit` for all files

```bash
npm run pre-commit
```

### If you need to add an ssh passphrase, then use ssh-add

```bash
eval "$(ssh-agent)"
ssh-add
```

Please note that this process has been added to the .bashrc file, and therefore it will automatically execute when you launch the Docker container.

### Error with `no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"`

```text
module.nginx.helm_release.nginx: Creating...
╷
│ Error: unable to build kubernetes objects from release manifest: resource mapping not found for name: "nginx-ingress-nginx-controller" namespace: "nginx" from "": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
│ ensure CRDs are installed first
│
│   with module.nginx.helm_release.nginx,
│   on nginx/main.tf line 7, in resource "helm_release" "nginx":
│    7: resource "helm_release" "nginx" {
```

This error occurs when Prometheus CRDs are not installed.

1. Go to `stage2/kubernetes/prometheus-crd.tf`
2. Uncomment the following line:

   ```text
   # always_run          = "${timestamp()}"
   ```

3. Re-run the following command:

   ```bash
   /srv/stage2# terraform apply
   ```

### When gitlab registry is full with storage backend

```bash
$ kubectl logs -ngitlab gitlab-registry-75dfc7f8df-snfgj
{"delay_s":0.637374452,"error":"XMinioStorageFull: Storage backend has reached its minimum free drive threshold. Please delete a few objects to proceed.\n\tstatus code: 507, request id: 17FB95EA70099F9E, host id: dd9025bab4ad464b049177c95eb6ebf374d3b3fd1af9251148b658df7ac2e3e8","level":"info","msg":"S3: retrying after error","time":"2024-10-05T14:48:36.162Z"}
```

Expand `data*-minio-tenant-pool-0-0` PVC

```bash
kubectl edit -nminio-tenant pvc data0-minio-tenant-pool-0-0
kubectl edit -nminio-tenant pvc data1-minio-tenant-pool-0-0
kubectl edit -nminio-tenant pvc data2-minio-tenant-pool-0-0
kubectl edit -nminio-tenant pvc data3-minio-tenant-pool-0-0
```

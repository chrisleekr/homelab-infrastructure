# Homelab Infrastructure - k3s/kubeadm/minikube + Kubernetes Infrastructure as a Code

> Provisioning Kubernetes with k3s/kubeadm/minikube, Ansible and Terraform

## What is this project about?

This project aims to provision Kubernetes on a Ubuntu server and consists of three stages:

- Stage 1: Ansible
  - Install fail2ban, disable multipath, setup ufw and other tasks.
  - Provision a single-node Kubernetes cluster using k3s or kubeadm.
    - **k3s**: Repository: <https://github.com/k3s-io/k3s-ansible>
    - **kubeadm**: <https://kubernetes.io/docs/reference/setup-tools/kubeadm/>
  
- Stage 2: Terraform
  - Nginx
  - Cert manager
  - Longhorn
  - Minio
  - Gitlab
  - Prometheus

## Prerequisite

1. Set up Terraform Cloud and create an API key.

2. Install Ubuntu AMD64 on a server.
   - Gitlab (`registry.gitlab.com/gitlab-org/build/cng/kubectl`) does not support ARM64 yet.

3. Node installed in your computer.

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

### Stage 1: Provision k3s

1. Add the public key located at ~/.ssh/id_rsa.pub to the authorized_keys file for the root user on Ubuntu.

2. Verify access by running the following commands:

    ```bash
    $ npm run docker:exec
    /srv# cd stage1
    /srv/stage1# ansible all -i "inventories/inventory.yml" -m ping
    ```

3. Prepare the VM template by running the following command:

    ```bash
    /srv/stage1# ansible-playbook --ask-become-pass -i "inventories/inventory.yml" site.yml
    BECOME password: <ubuntu root password>
    ```

    - At the end of the playbook, the `.kube/config` should be copied to the local machine in `container/root/.kube/config`.

### Stage 2: Launch VM for Kubernetes nodes

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

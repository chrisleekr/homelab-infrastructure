# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM alpine:3.20

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG BUILDARCH

ARG KUBECTL_VERSION=1.34.0
ARG HELM_VERSION=3.18.6
ARG TERRAFORM_VERSION=1.13.1
ARG TASKFILE_VERSION=3.44.1
ARG TRIVY_VERSION=0.66.0

# BUILDPLATFORM=linux/arm64/v8, TARGETPLATFORM=linux/arm64/v8, BUILDARCH=arm64
RUN echo "BUILDPLATFORM=$BUILDPLATFORM, TARGETPLATFORM=$TARGETPLATFORM, BUILDARCH=$BUILDARCH"

WORKDIR /srv

# For installing Ansible
COPY stage1/requirements* /tmp

WORKDIR /tmp

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

RUN set -eux; \
  \
  apk add --no-cache \
  ca-certificates=20250619-r0 \
  curl=8.12.1-r0 \
  bash=5.2.26-r0 \
  jq=1.7.1-r0 \
  bind-tools=9.18.39-r0 \
  git=2.45.4-r0 \
  graphviz=9.0.0-r2 \
  python3=3.12.11-r0 \
  py3-pip=24.0-r2 \
  pre-commit=3.7.1-r0 \
  shellcheck=0.10.0-r1 \
  bash-completion=2.12.0-r0 \
  && \
  \
  # Install kubectl - https://dl.k8s.io/release/v1.30.2/bin/linux/arm64/kubectl
  curl -L https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${BUILDARCH}/kubectl -o /usr/local/bin/kubectl && \
  chmod +x /usr/local/bin/kubectl && \
  kubectl version || true && \
  \
  # Install Helm - https://get.helm.sh/helm-v3.11.1-linux-arm64.tar.gz
  curl -L https://get.helm.sh/helm-v${HELM_VERSION}-linux-${BUILDARCH}.tar.gz | tar xz && \
  mv linux-${BUILDARCH}/helm /usr/local/bin/helm && \
  chmod +x /usr/local/bin/helm && \
  rm -rf linux-${BUILDARCH} && \
  helm version && \
  \
  # Install Terraform - https://releases.hashicorp.com/terraform/1.3.9/terraform_1.3.9_linux_arm64.zip
  curl -L https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${BUILDARCH}.zip -o terraform_${TERRAFORM_VERSION}_linux_${BUILDARCH}.zip && \
  unzip terraform_${TERRAFORM_VERSION}_linux_${BUILDARCH}.zip && \
  rm terraform_${TERRAFORM_VERSION}_linux_${BUILDARCH}.zip && \
  mv terraform /usr/local/bin/terraform && \
  terraform version && \
  \
  # Install Ansible
  apk add --no-cache \
  openssh=9.7_p1-r5 \
  sshpass=1.10-r0 \
  g++=13.2.1_git20240309-r1 \
  gcc=13.2.1_git20240309-r1 \
  libffi-dev=3.4.6-r0	\
  python3-dev=3.12.11-r0 \
  py3-pip=24.0-r2 && \
  # Setup Python virtual environment
  python3 -m venv .venv && \
  . .venv/bin/activate && \
  # Install Python packages
  pip install --no-cache-dir -r /tmp/requirements-pip.txt && \
  ansible --version && \
  # Run Ansible Galaxy to install required collections
  ansible-galaxy install -r /tmp/requirements.yml && \
  \
  # Install Taskfile
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin v${TASKFILE_VERSION} && \
  \
  # Install trivy - https://github.com/aquasecurity/trivy/releases
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v${TRIVY_VERSION} && \
  \
  # Install tflint
  curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash && \
  \
  # Install kubent - https://github.com/doitintl/kube-no-trouble
  sh -c "$(curl -sSL https://git.io/install-kubent)" && \
  \
  # Cleanup
  rm -rf /var/cache/apk/* /usr/share/doc /usr/share/man/ /usr/share/info/* /var/cache/man/* /tmp/*

WORKDIR /srv

COPY container/ /

COPY . .

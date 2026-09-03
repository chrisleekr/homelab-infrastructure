# syntax=docker/dockerfile:1
FROM alpine:3.24.1

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETARCH

# https://dl.k8s.io/release/stable.txt
ARG KUBECTL_VERSION=1.36.3
# https://github.com/helm/helm/releases
ARG HELM_VERSION=4.2.4
# https://developer.hashicorp.com/terraform/install
ARG TERRAFORM_VERSION=1.16.1
# https://github.com/go-task/task/releases
ARG TASKFILE_VERSION=3.53.1
# https://github.com/aquasecurity/trivy/releases
ARG TRIVY_VERSION=0.74.0
# https://github.com/terraform-linters/tflint/releases
ARG TFLINT_VERSION=v0.64.0
ARG TFLINT_SHA256_AMD64=cca9d13e2e1d7a2c627af60ff899a3c9b74212899416aeb96ec764d2ef954537
ARG TFLINT_SHA256_ARM64=560da89aacf59389d4eb029730dd5b109b7288096c32f2726a0d9e783a5ea8eb
# https://github.com/bitwarden/sdk-sm/releases
ARG BWS_VERSION=2.1.0
# https://github.com/oracle/oci-cli/releases
ARG OCI_CLI_VERSION=3.90.3

# Fail before installing target-specific binaries into a mismatched base image.
RUN case "${TARGETARCH}:$(apk --print-arch)" in \
  amd64:x86_64|arm64:aarch64) ;; \
  *) echo "target architecture mismatch: TARGETARCH=${TARGETARCH}, APK_ARCH=$(apk --print-arch)" && exit 1 ;; \
  esac && \
  echo "BUILDPLATFORM=$BUILDPLATFORM, TARGETPLATFORM=$TARGETPLATFORM, TARGETARCH=$TARGETARCH"

WORKDIR /srv

# For installing Ansible
COPY stage1/requirements* /tmp

WORKDIR /tmp

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# alpine:3.24.1 ships openssl 3.5.7-r0, which carries CVE-2026-14456. The v3.24 apk repo already
# has the fix, so libcrypto3 and libssl3 are pinned ahead of the base image until 3.24.2 is tagged.
RUN set -eux; \
  \
  apk add --no-cache \
  libcrypto3=3.5.8-r0 \
  libssl3=3.5.8-r0 \
  ca-certificates=20260611-r0 \
  curl=8.22.0-r0 \
  bash=5.3.9-r1 \
  jq=1.8.2-r0 \
  bind-tools=9.20.26-r0 \
  git=2.54.0-r0 \
  graphviz=12.2.1-r3 \
  python3=3.14.7-r1 \
  py3-pip=26.1.2-r0 \
  pre-commit=4.6.0-r0 \
  shellcheck=0.11.0-r1 \
  bash-completion=2.17.0-r1 \
  && \
  \
  # Install kubectl
  curl -fsSL https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl -o /usr/local/bin/kubectl && \
  chmod +x /usr/local/bin/kubectl && \
  kubectl version --client && \
  \
  # Install Helm - https://get.helm.sh/helm-v3.11.1-linux-arm64.tar.gz
  curl -L https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz | tar xz && \
  mv linux-${TARGETARCH}/helm /usr/local/bin/helm && \
  chmod +x /usr/local/bin/helm && \
  rm -rf linux-${TARGETARCH} && \
  helm version && \
  \
  # Install Terraform - https://releases.hashicorp.com/terraform/1.3.9/terraform_1.3.9_linux_arm64.zip
  curl -L https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip -o terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip && \
  unzip terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip && \
  rm terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip && \
  mv terraform /usr/local/bin/terraform && \
  terraform version && \
  \
  # Install Ansible
  apk add --no-cache \
  openssh=10.3_p1-r1 \
  sshpass=1.10-r0 \
  g++=15.2.0-r5 \
  gcc=15.2.0-r5 \
  libffi-dev=3.5.2-r1 \
  python3-dev=3.14.7-r1 && \
  # Setup Python virtual environment
  python3 -m venv .venv && \
  . .venv/bin/activate && \
  # Install Python packages
  pip install --no-cache-dir -r /tmp/requirements-pip.txt && \
  ansible --version && \
  # Run Ansible Galaxy to install required collections
  ansible-galaxy install -r /tmp/requirements.yml && \
  \
  # oci-cli, used only by the stage0 capacity pre-check in scripts/oci-apply-retry.sh, which
  # needs a stateless API call Terraform cannot make.
  #
  # Its own venv, not the Ansible one: oci-cli pins PyYAML<=6.0.2, which silently downgrades
  # the Ansible venv and breaks the kubernetes package's pyyaml>=6.0.3 requirement. Nothing
  # here imports oci as a library, so a symlinked console script is all that is needed.
  # System python by absolute path because the Ansible venv is active at this point.
  /usr/bin/python3 -m venv /opt/oci-cli && \
  /opt/oci-cli/bin/pip install --no-cache-dir oci-cli==${OCI_CLI_VERSION} && \
  ln -s /opt/oci-cli/bin/oci /usr/local/bin/oci && \
  oci --version && \
  \
  # Install Taskfile
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin v${TASKFILE_VERSION} && \
  \
  # Install trivy - https://github.com/aquasecurity/trivy/releases
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v${TRIVY_VERSION} && \
  \
  # Install TFLint from its pinned release archive.
  case "${TARGETARCH}" in \
  amd64) TFLINT_SHA256="${TFLINT_SHA256_AMD64}" ;; \
  arm64) TFLINT_SHA256="${TFLINT_SHA256_ARM64}" ;; \
  *) echo "unsupported arch for tflint: ${TARGETARCH}" && exit 1 ;; \
  esac && \
  TFLINT_ARCHIVE="tflint_linux_${TARGETARCH}.zip" && \
  TFLINT_BASE="https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}" && \
  curl -fsSL "${TFLINT_BASE}/${TFLINT_ARCHIVE}" -o "${TFLINT_ARCHIVE}" && \
  printf '%s  %s\n' "${TFLINT_SHA256}" "${TFLINT_ARCHIVE}" | sha256sum -c - && \
  unzip -o "${TFLINT_ARCHIVE}" -d /usr/local/bin && \
  chmod +x /usr/local/bin/tflint && \
  rm "${TFLINT_ARCHIVE}" && \
  tflint --version && \
  \
  # Install bws (Bitwarden Secrets Manager CLI). Native musl build, so no gcompat needed.
  # https://github.com/bitwarden/sdk-sm/releases
  case "${TARGETARCH}" in \
  amd64) BWS_TARGET="x86_64-unknown-linux-musl" ;; \
  arm64) BWS_TARGET="aarch64-unknown-linux-musl" ;; \
  *) echo "unsupported arch for bws: ${TARGETARCH}" && exit 1 ;; \
  esac && \
  BWS_BASE="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}" && \
  curl -fsSL "${BWS_BASE}/bws-${BWS_TARGET}-${BWS_VERSION}.zip" -o bws.zip && \
  curl -fsSL "${BWS_BASE}/bws-sha256-checksums-${BWS_VERSION}.txt" -o bws-sums.txt && \
  grep "bws-${BWS_TARGET}-${BWS_VERSION}.zip" bws-sums.txt | awk '{print $1"  bws.zip"}' | sha256sum -c - && \
  unzip -o bws.zip -d /usr/local/bin && \
  chmod +x /usr/local/bin/bws && \
  rm bws.zip bws-sums.txt && \
  bws --version && \
  \
  # Cleanup
  rm -rf /var/cache/apk/* /usr/share/doc /usr/share/man/ /usr/share/info/* /var/cache/man/* /tmp/*

ENV PATH="/tmp/.venv/bin:$PATH"

WORKDIR /srv

COPY container/ /

COPY . .

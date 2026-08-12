#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

CLUSTER="$1"

CLUSTER_PATH="tg/clusters/$CLUSTER"
CLUSTER_DIR="$DIR/../$CLUSTER_PATH"

if [ -d "$CLUSTER_DIR" ]; then
  echo "Path $CLUSTER_PATH already exists"
  exit 1
fi

mkdir -p "$CLUSTER_DIR"

cat <<EOF > "$CLUSTER_DIR/terragrunt.hcl"
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  cluster = "$CLUSTER"
}
EOF

cat <<EOF > "$CLUSTER_DIR/terraform.tfvars"
# Personal access token used for creating deploy keys.
# GitHub repositories authenticate via the GITHUB_TOKEN environment variable instead.
gitlab_token = null

# Specify private key for SSH access to the Git repository if you don't want to use PAT
# ssh-keygen -t ed25519 -C "fluxcd-deploy-key"
git_ssh_private_key = null

# Age private key used for encrypting secrets in the cluster.
age_private_key = null
EOF

[ -f "$DIR/../tg/clusters/terragrunt.tfvars" ] || cat <<EOF > "$DIR/../tg/clusters/terragrunt.tfvars"
backend = {
  type = "local"

  local = {
    path_prefix = ""
  }

  s3 = {
    endpoint      = null
    bucket        = ""
    region        = ""
    access_key    = ""
    secret_key    = ""
    object_prefix = ""
  }
}

# Cluster connection for the generated kubernetes/helm providers.
# cluster_ca_certificate, client_certificate and client_key are base64-encoded
# (as stored in a kubeconfig). Attributes left as null are omitted.
kubernetes = {
  host                   = "https://127.0.0.1:6443"
  cluster_ca_certificate = null
  token                  = null
  client_key             = null
  client_certificate     = null
  insecure               = false
}
EOF

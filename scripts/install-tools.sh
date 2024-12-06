#!/usr/bin/env bash

set -eo pipefail

has_cmd() {
  command -v "$1" >/dev/null
}

is_true() {
  if echo "$1" | grep -iqwE "(y(es)?|t(rue)?|1)"; then
    true
  else
    false
  fi
}

fetch() {
  if has_cmd curl; then
    if [ -n "$1" ]; then
      fetch="curl -sSfL -o $1"
    else
      fetch="curl -sSfL"
    fi
  elif has_cmd wget; then
    if [ -n "$1" ]; then
      fetch="wget -qO $1"
    else
      fetch="wget -qO-"
    fi
  else
    fatal "cannot get $2: command wget or curl not found"
    exit 1
  fi

  $fetch "$2"
}

fetch_bin() {
  fetch "${INSTALL_PREFIX}/$1" "$2"
  chmod +x "${INSTALL_PREFIX}/$1"
}

fetch_zip() {
  tmp_dir=$(mktemp -d)
  fetch "$tmp_dir/$1.zip" "$2"
  unzip -q "$tmp_dir/$1.zip" -d "$tmp_dir"
  mv "$tmp_dir/$1" "${INSTALL_PREFIX}/$1"
  rm -rf "$tmp_dir"
}

SOPS_VERSION="v3.9.0"
TERRAFORM_VERSION="1.9.4"
TERRAGRUNT_VERSION="v0.67.13"
YQ_VERSION="v4.44.3"

INSTALL_PREFIX="$(dirname "${BASH_SOURCE[0]}" )/../.bin"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)

if [ "$arch" = "x86_64" ]; then
  arch="amd64"
elif [ "$arch" = "aarch64" ]; then
  arch="arm64"
elif [ "$arch" = "i386" ]; then
  arch="386"
fi

mkdir -p "${INSTALL_PREFIX}"

if ! is_true "$ONLY_MISSING" || ! has_cmd sops; then
  echo "Downloading sops ${SOPS_VERSION}..."
  fetch_bin sops "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.${os}.${arch}"
  if ! sops --version >/dev/null; then
    echo "Error: sops ${SOPS_VERSION} ${os} ${arch} failed to install"
  fi
fi

if ! is_true "$ONLY_MISSING" || ! has_cmd yq; then
  echo "Downloading yq ${YQ_VERSION}..."
  fetch_bin yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${os}_${arch}"
  if ! yq --version >/dev/null; then
    echo "Error: yq ${YQ_VERSION} ${os} ${arch} failed to install"
  fi
fi

if ! is_true "$ONLY_MISSING" || ! has_cmd terraform; then
  echo "Downloading terraform ${TERRAFORM_VERSION}..."
  fetch_zip terraform "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${os}_${arch}.zip"
  if ! terraform --version >/dev/null; then
    echo "Error: terraform ${TERRAFORM_VERSION} ${os} ${arch} failed to install"
  fi
fi

if ! is_true "$ONLY_MISSING" || ! has_cmd terragrunt; then
  echo "Downloading terragrunt ${TERRAGRUNT_VERSION}..."
  fetch_bin terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_${os}_${arch}"
  if ! terragrunt --version >/dev/null; then
    echo "Error: terragrunt ${TERRAGRUNT_VERSION} ${os} ${arch} failed to install"
  fi
fi

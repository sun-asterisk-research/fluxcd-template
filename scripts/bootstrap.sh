#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR/lib.sh"

COMMAND="${1:-apply}"
CLUSTER="$2"

git_ref="$(git symbolic-ref -q HEAD)"
git_upstream="$(git for-each-ref --format='%(upstream:short)' "$git_ref")"

TF_VAR_git_remote="$(echo "$git_upstream" | cut -d/ -f1)"
TF_VAR_git_branch="$(echo "$git_upstream" | cut -d/ -f2)"

# Derive the repo URL from the local remote unless the caller already set it.
if [ -z "${TF_VAR_git_url:-}" ]; then
  TF_VAR_git_url="$(git remote get-url "$TF_VAR_git_remote" | sed -E 's#^([^@]+)@([^:]+):#ssh://\1@\2/#')"

  # Resolve SSH host aliases (~/.ssh/config) to the real hostname. Aliases only
  # exist on this machine: Flux inside the cluster cannot resolve them, and the
  # module's SCM detection would misclassify the provider.
  if [[ "$TF_VAR_git_url" =~ ^ssh://([^@/]+)@([^/:]+)(:([0-9]+))?(/.*)$ ]]; then
    ssh_user="${BASH_REMATCH[1]}"
    ssh_host="${BASH_REMATCH[2]}"
    ssh_port="${BASH_REMATCH[4]}"
    repo_path="${BASH_REMATCH[5]}"

    ssh_config="$(ssh -G "$ssh_host" 2>/dev/null)"
    resolved_host="$(echo "$ssh_config" | awk '/^hostname /{print $2; exit}')"
    resolved_port="$(echo "$ssh_config" | awk '/^port /{print $2; exit}')"

    if [ -n "$resolved_host" ]; then
      port_suffix=""
      if [ -n "$ssh_port" ]; then
        port_suffix=":$ssh_port"
      elif [ -n "$resolved_port" ] && [ "$resolved_port" != "22" ]; then
        port_suffix=":$resolved_port"
      fi
      TF_VAR_git_url="ssh://$ssh_user@$resolved_host$port_suffix$repo_path"
    fi
  fi
fi

export TF_VAR_git_remote
export TF_VAR_git_url
export TF_VAR_git_branch
export TG_NO_AUTO_APPROVE=true
export TG_WORKING_DIR="$DIR/../tg/clusters/$CLUSTER"

terragrunt $COMMAND

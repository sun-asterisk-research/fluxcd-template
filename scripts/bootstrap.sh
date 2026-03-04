#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR/lib.sh"

COMMAND="${1:-apply}"
CLUSTER="$2"

git_ref="$(git symbolic-ref -q HEAD)"
git_upstream="$(git for-each-ref --format='%(upstream:short)' "$git_ref")"

TF_VAR_git_remote="$(echo "$git_upstream" | cut -d/ -f1)"
TF_VAR_git_url="$(git remote get-url "$TF_VAR_git_remote" | sed -E 's#^([^@]+)@([^:]+):#ssh://\1@\2/#')"
TF_VAR_git_branch="$(echo "$git_upstream" | cut -d/ -f2)"

export TF_VAR_git_remote
export TF_VAR_git_url
export TF_VAR_git_branch
export TG_NO_AUTO_APPROVE=true
export TG_WORKING_DIR="$DIR/../tg/clusters/$CLUSTER"

terragrunt $COMMAND

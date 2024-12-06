#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR/lib.sh"

COMMAND="${1:-apply}"
CLUSTER="$2"

git_ref="$(git symbolic-ref -q HEAD)"
git_upstream="$(git for-each-ref --format='%(upstream:short)' "$git_ref")"

TF_VAR_git_remote="$(echo "$git_upstream" | cut -d/ -f1)"
TF_VAR_git_url="$(git remote get-url "$TF_VAR_git_remote")"
TF_VAR_git_branch="$(echo "$git_upstream" | cut -d/ -f2)"

export TF_VAR_git_remote
export TF_VAR_git_url
export TF_VAR_git_branch

terragrunt --terragrunt-working-dir "$DIR/../tg/clusters/$CLUSTER" "$COMMAND"

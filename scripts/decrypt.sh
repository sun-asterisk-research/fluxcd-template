#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR/lib.sh"

COMMAND="${1:-apply}"

terragrunt --terragrunt-working-dir tg/secrets/decrypt "$COMMAND"

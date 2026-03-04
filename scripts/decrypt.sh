#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR/lib.sh"

COMMAND="${1:-apply}"

export TG_WORKING_DIR="tg/secrets/decrypt"

terragrunt "$COMMAND"

#!/usr/bin/env bash

terragrunt() {
  tg_version="$(command terragrunt --version | awk '{print $3}')"

  TERRAGRUNT_LOG_LEVEL=info

  if [ "$DEBUG" != "true" ]; then
    if [[ "v${tg_version%v}" > "v0.67" ]]; then
      export TERRAGRUNT_LOG_DISABLE=1
    else
      TERRAGRUNT_LOG_LEVEL=fatal
    fi
  fi

  export TERRAGRUNT_LOG_LEVEL

  command terragrunt "$@"
}

prompt() {
  printf "%s" "$@" 1>&2
  read -r ans </dev/tty
  echo "$ans"
}

#!/usr/bin/env bash

terragrunt() {
  tg_version="$(command terragrunt --version | awk '{print $3}')"

  TG_LOG_LEVEL=info

  if [ "$DEBUG" != "true" ]; then
    if [[ "v${tg_version%v}" > "v0.67" ]]; then
      export TG_LOG_DISABLE=1
    else
      TG_LOG_LEVEL=fatal
    fi
  fi

  export TG_LOG_LEVEL

  if [[ "v${tg_version%v}" < "v0.77.22" ]]; then
    for tg_var in $(env | grep '^TG_' | cut -d= -f1); do
      terragrunt_var="TERRAGRUNT_${tg_var#TG_}"
      export "$terragrunt_var"="${!tg_var}"
    done
  fi

  command terragrunt "$@"
}

prompt() {
  printf "%s" "$@" 1>&2
  read -r ans </dev/tty
  echo "$ans"
}

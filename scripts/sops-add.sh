#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR/lib.sh"

SOPS_FILE="$DIR/../sops.yaml"

NAME="$1"
GROUP="$2"
TYPE="$3"
RECIPIENT="$4"

if [ -z "$NAME" ]; then
  NAME="$(prompt "Enter recipient name: ")"
fi

if [ -z "$RECIPIENT" ]; then
  RECIPIENT="$(prompt "Enter $TYPE recipient: ")"
fi

yq_script=".recipients.\"$NAME\".$TYPE = \"$RECIPIENT\""

IFS=','; for group in $GROUP; do
  yq_script="$yq_script | .\".groups\".\"$group\" += [\"$NAME\"] | .\".groups\".\"$group\" anchor = \"$group\""
done

yq -i "$yq_script" "$SOPS_FILE"

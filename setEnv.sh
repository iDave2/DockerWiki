#!/usr/bin/env bash
#
#  Source this file for convenient shortcuts.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# https://stackoverflow.com/a/246128
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

alias br="${SCRIPT_DIR}/bin/backrest.sh"
alias cake="${SCRIPT_DIR}/bin/cake.sh"
alias d=docker
alias dc="docker compose"
alias dp="declare -p"
alias sp="${SCRIPT_DIR}/bin/setPasswords.sh"
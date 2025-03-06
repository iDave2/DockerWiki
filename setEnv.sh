#!/usr/bin/env bash
#
#  Source this file for convenient shortcuts.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# https://stackoverflow.com/a/246128
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

alias d=docker
alias dc="docker compose"
alias dp="declare -p"

# Or simply export PATH=${ScriptDir}:$PATH?
alias backrest="${SCRIPT_DIR}/bin/backrest.sh"
alias cake="${SCRIPT_DIR}/bin/cake.sh"
alias config="${SCRIPT_DIR}/bin/configure.sh"
alias sp="${SCRIPT_DIR}/bin/setPasswords.sh"

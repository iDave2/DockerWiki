#!/usr/bin/env bash
#
#  Source this for a recommended development environment.
#
#  At least update PATH (see below) for scripts to work.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# https://stackoverflow.com/a/246128
ScriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

PATH=${ScriptDir}/bin:$PATH

alias d=docker
alias dc="docker compose"
alias dp="declare -p"

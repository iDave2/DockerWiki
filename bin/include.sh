#!/usr/bin/env bash
#
#  Helpers to be sourced.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

set -uo pipefail # pipe status is last-to-fail or zero if none fail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../.env" # https://stackoverflow.com/a/246128
source "$USER_CONFIG" 2>/dev/null

# Additional variables declared at EOF after functions available.
DECORATE=true # see --no-decoration and decorate()

####-####+####-####+####-####+####-####+
#
#  Curly version of xShow, this pretty-prints comment + command.
#
cShow() {
  local comment="$1" command="$2"
  echo -e "\n# $comment\n\$ $command"
}

####-####+####-####+####-####+####-####+
#
#  Decorate generated artifact names; emulate docker compose.
#
decorate() {
  local name="$1" project="$2" type="$3"
  local result=$name
  if $DECORATE; then
    case $type in
    'container')
      result="${project}-${name}-1"
      ;;
    'network' | 'volume')
      result="${project}_${name}"
      ;;
    esac
  fi
  echo $result
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Prints given message and dies. usage() is gentler.
#
die() {
  echo -e "\n$*"
  exit 42
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Function returns container name of a given service name.
#  For example, 'data' => 'wiki-data-1' unless --no-decoration.
#
getContainer() {
  local service
  case "$1" in
  $DATA_SERVICE | $VIEW_SERVICE)
    service="$1"
    ;;
  *)
    usage "getContainer: expected '$DATA_SERVICE' or '$VIEW_SERVICE', not '$1'"
    ;;
  esac
  echo $(decorate "$service" "$PROJECT" 'container')
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  I smell Windows.
#
getLastError() { cat "$errFile"; }
getLastOutput() { cat "$outFile"; }

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Apple getopt is clunky, gnu-getopt is great, but Apple warns we're all
#  gonna die if gnu-getopt is in PATH, so...
#
#  Imitate a small but useful part of gnu-getopt: -abcd -> -a -b -c -d.
#
getOpt() {
  local newArgs='' # modified options `n arguments
  while [[ $# -gt 0 ]]; do
    # echo "getOpt: Checking '$1'"
    if [[ "$1" =~ ^-[_[:alnum:]]{2,} ]]; then
      # echo "  '$1' matches, is splittable"
      for ((i = 1; i < ${#1}; ++i)); do
        newArgs+=" -${1:$i:1}"
      done
    else
      # echo "  '$1' does not match, keep as is"
      newArgs+=" $1"
    fi
    shift
  done
  # echo "getOpt: newArgs = '$newArgs'"
  echo $newArgs
}

####-####+####-####+####-####+####-####+
#
#  Rather than having everyone creating folders, how about,
#
getTempDir() {
  if [ ! -d "$TEMP_DIR" ]; then
    mkdir "$TEMP_DIR" && [ -d "$TEMP_DIR" ] ||
      die "Error: cannot create temporary directory, '$TEMP_DIR'!"
  fi
  echo $TEMP_DIR
}

####-####+####-####+####-####+####-####+
#
#  Underrated indeed: https://stackoverflow.com/a/55283209
#
isDockerRunning() {
  docker info >/dev/null 2>&1
}

####-####+####-####+####-####+####-####+
#
#  Join list with a given delimiter: "$(join ', ' A 'B C' D)" => "A, B C, D"
#
join() { # https://stackoverflow.com/a/17841619
  local c="" d="$1" r=""
  shift
  for arg; do
    r="$r$c$arg"
    c=$d
  done
  echo $r
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  On the never-ending quest to make code more readable, memorable, brief,
#  blah blah blah, these helpers may be handy.
#
#  The xCute variants call xShow for a pretty display of what it will do
#  before it does it; xQute flavors are Quiet, they just run the command
#  with any requested redirection.
#
#  The redirection notation -- xCute2, xQute12, etc. -- seems clear enough;
#  redirected streams from most recent x[CQ]ute may be retrieved with
#  $(getLastError) and $(getLastOutput).
#
#  TODO: PIPESTATUS?
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
xShow() {
  local options="$1"
  if [ "${options:0:1}" = "-" ]; then
    shift
  else
    options="-e"
  fi
  echo "$options" "\n[$(basename $(pwd))] \$ $*"
}

xCute() {
  xShow "$@"
  "$@"
}
xCute1() {
  xShow "$@"
  "$@" 1>"$outFile"
}
xCute2() {
  xShow "$@"
  "$@" 2>"$errFile"
}
xCute12() {
  xShow "$@"
  "$@" 1>"$outFile" 2>"$errFile"
}

xQute() { "$@"; }
xQute1() { "$@" 1>"$outFile"; }
xQute2() { "$@" 2>"$errFile"; }
xQute12() { "$@" 1>"$outFile" 2>"$errFile"; }

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Variable definitions down here as some require functions above.
#  Let's try camel case for file scope hint, uppercase for globals?
#
readonly errFile="$(getTempDir)/stderr"
readonly outFile="$(getTempDir)/stdout"

# Make these always exist.
cat </dev/null >"$errFile"
cat </dev/null >"$outFile"

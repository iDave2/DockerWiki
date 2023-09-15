#!/usr/bin/env bash
#
#  Helpers to be sourced.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../.env" # https://stackoverflow.com/a/246128
source "$USER_CONFIG" 2>/dev/null

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Prints given message and dies. usage() is gentler.
#
abend() {
  echo -e "\n$*"
  exit 42
}

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
#  Function returns container name of a given service name.
#  For example, 'data' => 'wiki-data-1' unless --no-decoration.
#
getContainer() {
  local service
  case "$1" in
  data)
    service="$DW_DATA_SERVICE"
    ;;
  view)
    service="$DW_VIEW_SERVICE"
    ;;
  *)
    usage "getContainer: expected 'data' or 'view', not '$1'"
    ;;
  esac
  echo $(decorate "$service" "$DW_PROJECT" 'container')
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  I smell Windoze.
#
getLastError() {
  [ -f "$errFile" ] && cat "$errFile" || echo
}

####-####+####-####+####-####+####-####+
#
#  Rather than having everyone creating folders, how about,
#
getTempDir() {
  if [ ! -d "$TEMP_DIR" ]; then
    mkdir "$TEMP_DIR" && [ -d "$TEMP_DIR" ] ||
      abend "Error: cannot create temporary directory, '$TEMP_DIR'!"
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

####-####+####-####+####-####+####-####+
#
#  Pretty-print commands executed and save output in array LINES, sometimes.
#
LINES=()
xShow() {
  local options="$1"
  [ "${options:0:1}" = "-" ] && shift || options="-e"
  echo "$options" "\n[$(basename $(pwd))] \$ $*"
}
xCute() { # https://stackoverflow.com/a/32931403
  xShow "$@"
  IFS=$'\n' read -r -d '' -a LINES < <("$@" && printf '\0')
  printf "%s\n" "${LINES[@]}"
}
xIn() {
  local in="$1"
  shift
  # echo xIn\( $(join ', ' "$@") \)
  xShow "$@" "< $in"
  "$@" <$in
}
xOut() {
  local out="$1"
  shift
  # echo xOut\( $(join ', ' "$@") \)
  xShow "$@" "> $out"
  "$@" >$out
}
x2to1() { # Capture stderr for caller...
  xShow "$@"
  echo $("$@" 2>&1)
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Earlier whining notwithstanding, docker appears to return stdout, stderr
#  and $? normally. It can be tricky to separate and monitor all of them.
#
xKute() {
  xShow "$@"
  "$@" 2>"$errFile"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Variable definitions down here as some require functions above.
#  Let's try camel case for file scope hint, all uppercase for globals.
#
DECORATE=true # see --no-decoration
errFile="$(getTempDir)/stderr"

#!/usr/bin/env bash
#
#  Helpers to be sourced.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Additional variables declared at EOF after functions are visible.
DECORATE=true # see --no-decoration and decorate()

####-####+####-####+####-####+####-####+
#
#  Open default browser with the given URL.
#
browse() {
  local url="$1"
  test -n $url || die "browse(): please specify <url> to open"
  open $url # Also see https://stackoverflow.com/a/23039509.
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
#  Prints given message and dies. usage() is gentler.
#
die() {
  test $# -gt 0 && echo && echo $* # https://stackoverflow.com/q/3601515
  echo
  echo Death caused by ${FUNCNAME[1]}:${BASH_LINENO[0]} at $(date +%H:%M).
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
  $DW_DATA_SERVICE | $DW_VIEW_SERVICE)
    service="$1"
    ;;
  *)
    usage "getContainer: expected '$DW_DATA_SERVICE' or '$DW_VIEW_SERVICE', not '$1'"
    ;;
  esac
  echo $(decorate "$service" "$DW_PROJECT" 'container')
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
  if [ ! -d "$DW_TEMP_DIR" ]; then
    mkdir "$DW_TEMP_DIR" && [ -d "$DW_TEMP_DIR" ] ||
      die "Error: cannot create temporary directory, '$DW_TEMP_DIR'!"
  fi
  echo $DW_TEMP_DIR
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
#  Wait for the given URL to respond. Return true if site responds
#  before timing out; otherwise, return false.
#
waitForView() {
  local url=$1 seconds=${2:-10} isUp=false timer
  for ((timer = $seconds; timer > 0; --timer)); do
    echo waitForView: timer=$timer
    # xQute12 curl -sS $url && isUp=true && break
    xCute curl --head $url && isUp=true && break
    sleep 1
  done
  echo "waitForView done:\n" && cat "$(getLastOutput)"
  $isUp
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Adventures in preprocessing...
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

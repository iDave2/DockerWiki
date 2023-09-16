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
# xIn() {
#   local in="$1"
#   shift
#   # echo xIn\( $(join ', ' "$@") \)
#   xShow "$@" "< $in"
#   "$@" <$in
# }
# xOut() {
#   local out="$1"
#   shift
#   # echo xOut\( $(join ', ' "$@") \)
#   xShow "$@" "> $out"
#   "$@" >$out
# }
# x2to1() { # Capture stderr for caller...
#   xShow "$@"
#   echo $("$@" 2>&1)
# }

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Earlier whining notwithstanding, docker appears to return stdout, stderr
#  and $? normally. It can be tricky to separate and monitor all of them.
#  In particular, it is EASY to lose volatile $?, the status of last
#  command run by these helpers. The following patterns work consistently:
#
#    local out=$(xKute stuff) status=$?
#    # check status, handle result
#
#  or
#
#    local out=$(xKute stuff)
#    if [ $? -ne 0 ]; then ...
#
#  IOW, save or handle return status $? Immediately.
#
#  The xKute variants call xShow for a pretty display of what it will do
#  before it does it; xQute flavors are Quiet, they just run the command
#  with any requested redirection.
#
#  The redirection notation -- xKute2, xQute12, etc. -- seems clear enough;
#  redirected streams from most recent x[KQ]ute may be retrieved with
#  $(getLastError) and $(getLastOutput).
#
#  Use 'xKute' and 'xQute' going forward; 'xCute' will be deprecated away
#  soon; xShow is straightforward and will remain.
#
#  TODO: PIPESTATUS?
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
xKute() {
  xShow "$@"
  "$@"
}
xKute1() {
  xShow "$@"
  "$@" 1>"$outFile"
}
xKute2() {
  xShow "$@"
  "$@" 2>"$errFile"
}
xKute12() {
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
#  Let's try camel case for file scope hint, uppercase for globals.
#
DECORATE=true # see --no-decoration
errFile="$(getTempDir)/stderr"
outFile="$(getTempDir)/stdout"

# Make these always exist.
cat </dev/null >"$errFile"
cat </dev/null >"$outFile"

#!/usr/bin/env bash
#
#  Helpers to be sourced.
#
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
  case $type in
  'container')
    result="${project}-${name}-1"
    ;;
  'network' | 'volume')
    result="${project}_${name}"
    ;;
  esac
  echo $result
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
  echo && echo "[$(basename $(pwd))] \$ $*"
}
xCute() { # https://stackoverflow.com/a/32931403
  xShow "$@"
  IFS=$'\n' read -r -d '' -a LINES < <("$@" && printf '\0')
  # Seriously though, that's worse than perl ... ;)
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

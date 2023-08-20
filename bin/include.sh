#!/usr/bin/env bash
#
#  Helpers to be sourced.
#

# Join list with a given delimiter: "$(join ', ' A 'B C' D)" => "A, B C, D"
join() { # https://stackoverflow.com/a/17841619
  local c="" d="$1" r=""
  shift
  for arg; do
    r="$r$c$arg"
    c=$d
  done
  echo $r
}

# Pretty-print commands executed and save output in array LINES, sometimes.
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
  local in=$1
  shift
  # echo xIn\( $(join ', ' "$@") \)
  xShow "$@" "< $in"
  "$@" < $in
}
xOut() {
  local out=$1
  shift
  # echo xOut\( $(join ', ' "$@") \)
  xShow "$@" "> $out"
  "$@" > $out
}

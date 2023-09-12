#!/usr/bin/env bash
#
#  Helpers to be sourced.
#

# Referencing an array variable without a subscript
# is equivalent to referencing element zero. -[bash]
TRACE='eval echo $FUNCNAME[$LINENO]'

####-####+####-####+####-####+####-####+
#
#  Curly version of xShow, this pretty-prints comment + command.
#
cShow() {
  local comment=$1 command=$2
  echo && echo "# $comment" && echo "\$ $command"
}

####-####+####-####+####-####+####-####+
#
#  Decorate generated artifact names; emulate docker compose.
#
decorate() {
  local name=$1 project=$2 type=$3
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

# ####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
# #
# #  Remove leading and trailing space from a given string.
# #  https://stackoverflow.com/a/9733456 ++
# #
# trim() {
#   # sed -Ee s/^\w*// -Ee s/\w*$// <<<"$1"
#   perl -pwe 's/^\s*//' <<<"$1"
# }

####-####+####-####+####-####+####-####+
#
#  Pretty-print commands executed and save output in array LINES, sometimes.
#
LINES=()
xShow() {
  # echo -e "\n=> xShow(" $(join ', ' "$@") ")\n"
  # local words=() # Try, oh try to preserve almighty bash words.
  # for arg; do
  #   [[ "$arg" =~ \' ]] && words+=(\"$arg\") ||
  #     [[ "$arg" =~ \" ]] && words+=(\'$arg\') ||
  #     [[ "$arg" =~ "\ " ]] && words+=(\"$arg\") ||
  #     words+=($arg)

  #   # if [[ "$arg" =~ \' ]]; then
  #   #   words+=( \"$arg\" )
  #   # elif [[ "$arg" =~ \" ]]; then
  #   #   words+=( \'$arg\' )
  #   # elif [[ "$arg" =~ "\ " ]]; then
  #   #   words+=( \"$arg\" )
  #   # else
  #   #   words+=( $arg )
  #   # fi
  # done
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
  "$@" <$in
}
xOut() {
  local out=$1
  shift
  # echo xOut\( $(join ', ' "$@") \)
  xShow "$@" "> $out"
  "$@" >$out
}
x2to1() { # Capture stderr for caller...
  xShow "$@"
  echo $("$@" 2>&1)
}

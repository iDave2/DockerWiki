#!/usr/bin/env bash
#
#  Helpers to be sourced.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Additional variables declared at EOF after functions are visible.
DECORATE=true # see --no-decoration and decorate()

# Hide and show (generate) secrets.
readonly SecretHide='%%wgSecretKey%%'
unset SecretShow

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
#  TODO: This should write to stderr someday.
#
die() {
  test $# -gt 0 && echo -e "\n$*\n" >&2 # https://stackoverflow.com/q/3601515
  echo >&2
  echo Death caused by ${FUNCNAME[1]}:${BASH_LINENO[0]} at $(date +%H:%M). >&2
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
#  Wait for the given URL to return an HTTP status code less than 400.
#
#  Args:
#    $1 = URL to query
#    $2 = optional timeout in seconds; default 10
#
#  Return true if site responds in time; else false.
#
waitForView() {
  local url=$1 seconds=${2:-10} isUp=false timer http status message
  for ((timer = $seconds; timer > 0; --timer)); do
    echo -e "\n$ read http status message < <(curl -ISs $url)"
    if read http status message 2>"$errFile" < <(curl -ISs $url); then
      echo "out>" $http $status $message
      test ${status:-500} -lt 400 && isUp=true && break
    else
      echo "err> $(getLastError)"
    fi
    sleep 1
  done
  $isUp
}

####-####+####-####+####-####+####-####+
#
#  This filter expects to be inside a pipe streaming LocalSettings.php
#  to or from a MediaWiki container's /var/www/html folder. It takes
#  one argument, 'hide' or 'show'.
#
#  'hide' is used during backups to replace a live $wgSecretKey with
#  the string '%%wgSecretKey%%'.
#
#  'show' works in the opposite direction, replacing '%%wgSecretKey%%'
#  with a fresh 64-character random string.
#
#  Examples:
#    # Hiding is straightforward:
#    $ docker exec wiki-view-1 cat LocalSettings.php | wgSecretKey hide | ...
#
#    # Showing is awkward, so far:
#    $ $(... | wgSecretKey show >tmpFile) &&
#        docker cp tmpFile wiki-view-1:/var/www/html/LocalSettings.php &&
#        rm tmpFile
#
#  Also see:
#    https://stackoverflow.com/a/66461030.
#
#  Note: This algorithm was motivated by github warnings apparently triggered
#  by conditions name=LocalSettings.php and $wgSecretKey=<clearkey>. The
#  MediaWiki DB user password is still clear (in case you want to generalize
#  this). Also see usage in MediaWiki Dockerfile. And revisit docker secrets.
#
#  TODO: Do docker secrets persist? Are they initialized once or remain live?
#
wgSecretKey() {

  local action=${1:-unset}

  case $action in
  hide | show) ;;
  *) usage "wgSecretKey [hide | show], not '\$1 $action'" ;;
  esac

  if test -z ${SecretShow:-''}; then
    readonly Hex=$(echo {0..9} {a..f} | tr -d ' ') # 0123456789abcdef
    for i in {1..64}; do
      SecretShow+=${Hex:((RANDOM % ${#Hex})):1} # Tsoj2 dowsth!
    done
    readonly SecretShow
  fi

  case $action in
  hide) perl -pwe 's|^(\$wgSecretKey)\s*=.*|$1 = "%%wgSecretKey%%";|' ;;
  show) perl -pwe "s|$SecretHide|$SecretShow|" ;;
  esac
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

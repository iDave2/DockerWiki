#!/usr/bin/env bash
#
#  Helpers to be sourced.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Additional variables declared at EOF after functions are visible.
DECORATE=true # see --no-decoration and decorate()

unset wgServer # see getServer()

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
  test $# -gt 0 && echo -e "\n$*" >&2 # https://stackoverflow.com/q/3601515
  echo >&2
  echo Death caused by ${FUNCNAME[1]}:${BASH_LINENO[0]} at $(date +%H:%M). >&2
  exit 42
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Shorthand for: die "Error: $(getLastError)"
#
dieLastError() {
  (echo; echo "Error: $(getLastError)"; echo) >&2
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

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
getServer() {
  if test -z ${wgServer:-''}; then
    local host=127.0.0.1
    local map=($(echo $MW_PORTS | tr ':' ' '))
    local port=${map[-2]}
    if test ${#map[@]} -gt 2 -a -n "${map[-3]}"; then
      host=${map[-3]}
    fi
    wgServer="http://$host:$port"
  fi
  echo $wgServer
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Function returns the .State.Status of a given container. Returned
#  status values have the form '"running"' where the double quotes are
#  part of the string. Errors can be multiline so are collapsed into one
#  line and quoted for simpler presentation.
#
#  From 'docker ps' dockumentation circa 2023, container status can be one
#  of created, restarting, running, removing, paused, exited, or dead.
#  See https://docs.docker.com/engine/reference/commandline/ps/.
#
#  Also see https://docs.docker.com/config/formatting/.
#
getState() {

  (($# >= 2 && $# % 2 == 0)) ||
    die "Error: getState() requires an even number of arguments"

  local inspect='docker inspect --format' goville='{{json .State.Status}}'

  for ((i = 1; i < $#; i += 2)); do
    local j=$((i + 1))
    local container="${!i}" __result="${!j}" options
    ((i + 2 < $#)) && options="-en" || options="-e"
    xShow $options $inspect \"$goville\" $container
    local state=$(echo $($inspect "$goville" $container 2>&1))
    [ "${state:0:1}" = \" ] || state=\"$state\"
    eval $__result=$state
  done
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

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Wait for the database to become usable. While 'docker inspect' may show
#  mariadb "running", it may not be "connectable" when initializing a new
#  or restored database.
#
waitForData() {

  local timeout=${1:-10} isUp=false dataState viewState
  local dataContainer=$(getContainer $DW_DATA_SERVICE)
  local viewContainer=$(getContainer $DW_VIEW_SERVICE)
  local format="\n==> Container status: %s is \"%s\", %s is \"%s\" <==\n"

  # Start the database. No, that is caller's job.

  # xCute2 docker start $dataContainer || die "Error: $(getLastError)"

  # Smell the roses.

  getState $dataContainer dataState $viewContainer viewState
  printf "$format" $dataContainer $dataState $viewContainer $viewState

  # Wait for a query to work.

  for ((i = 0; i < $timeout; ++i)); do
    xCute docker exec $dataContainer /root/mariadb-show-databases &&
      isUp=true && break
    sleep 1
  done

  # Sniff again.

  getState $dataContainer dataState $viewContainer viewState
  printf "$format" $dataContainer $dataState $viewContainer $viewState

  # Report.

  $isUp
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

  # local url=$1 seconds=${2:-10} isUp=false timer http status message
  local url=$(getServer) seconds=${1:-10} isUp=false
  local timer http status message

  # Start the view. No, caller handles this...

  # xCute2 docker start $DW_VIEW_HOST || die "Error: $(getLastError)"

  # Sample headers returned from view container.

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

  # Report.

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

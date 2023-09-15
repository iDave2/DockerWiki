#!/usr/bin/env bash
#
#  Backup and restore tools adapted from hub pages for official
#  mediawiki and mariadb images.
#
#  This script passes cleartext passwords so is Not Secure.
#  This script requires 'bash' and 'jq'.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

set -euo pipefail # pipe status is last-to-fail or zero if none fail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/include.sh" # https://stackoverflow.com/a/246128

# What to do.
BACKUP=false
QUIET=true
RESTORE=false

# Where to do it.
wikiRoot="/var/www/html" # docroot inside view container
hostRoot="$(getTempDir)/backup-$(date '+%y%m%d-%H%M%S')"
dataFile="$hostRoot/all-databases.sql"
imageDir="$hostRoot/images"
localSettings="$wikiRoot/LocalSettings.php"

# Defaults subject to change via command line options.
dataContainer=$(getContainer data)
viewContainer=$(getContainer view)

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Validate requested data and view containers.
#
checkContainer() {

  local container=$1 hostName=$2 imageName=$3

  local inspect="docker container inspect $container"
  local jayQ="jq --raw-output"
  local filter=".[0].Config.Hostname, .[0].Config.Image"

  xShow $inspect '|' $jayQ "'$filter'"

  xQute12 $inspect
  [ $? -ne 0 ] && abend "Error: failed to inspect '$container': $(getLastError)"

  local hostImage=$(echo $(getLastOutput | $jayQ "$filter"))
  local hostTest=$(echo $hostImage | cut -w -f 1)
  local imageTest=$(echo $hostImage | cut -w -f 2)
  echo "$hostTest $imageTest"
  imageTest=$(echo $(basename $imageTest) | sed -e s/:.*//)
  # idave2/mariadb:0.2.0 => mariadb

  if [ "$hostTest" != "$hostName" ]; then
    usage "Expected host name '$hostName' for container '$container'; found '$hostTest' instead"
  fi
  if [ "$imageTest" != "$imageName" ]; then
    usage "Expected image name '$imageName' for container '$container'; found '$imageTest' instead"
  fi
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  chatgpt://get/quote?keyword="main"&limit=1
#
test() { # test getopts
  optstring='bD:hrV:vw:'
  echo "test[$LINENO]: optstring = '$optstring', \$# = '$#', \"\$@\" = ("$(join ', ' "$@")")"
  while getopts 'bD:hrV:vw:' option; do
    echo "option[$option], OPTIND[$OPTIND], OPTARG[$OPTARG]"
  done
}
main() {

  # Test getOpt().
  echo "main: incoming args: (" $(join ', ' "$@") ")"
  set -- $(getOpt "$@")
  echo "main: adjusted args: (" $(join ', ' "$@") ")"
  return

  isDockerRunning ||
    abend "This program uses docker which appears to be down; aborting."

  parseCommandLine "$@"

  ! $BACKUP && ! $RESTORE &&
    usage "Please specify --backup or --restore (or both FWIW)"

  checkContainer $dataContainer $DW_DATA_HOST mariadb # $DW_DATA_IMAGE=mariadb?
  checkContainer $viewContainer $DW_VIEW_HOST mediawiki

  if ! $QUIET; then
    echo
    for name in dataContainer viewContainer hostRoot dataFile imageDir localSettings; do
      printf "%13s = %s\n" $name ${!name}
    done
  fi

  xKute2 mkdir "$hostRoot" "$imageDir" # 1 second granularity
  [ $? -ne 0 ] && abend "Unable to create directory '$hostRoot': $(getLastError)"

  if $BACKUP; then

    local command="docker exec $dataContainer "
    command+="mariadb-dump --all-databases -uroot -p$DW_DB_ROOT_PASSWORD"
    xShow "$command | gzip > \"${dataFile}.gz\""
    $command | gzip >"${dataFile}.gz"
    [ $? -ne 0 ] && abend "Error backing up database; exit status '$?'."

    local commandA="docker exec $viewContainer tar -cC $wikiRoot/images ."
    local commandB="tar -xC ${hostRoot}/images"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && abend "Error backing up images; exit status '$?'."

    xKute2 docker cp "$viewContainer:$localSettings" "$hostRoot/$(basename $localSettings)"
    [ $? -ne 0 ] && abend "Error backing up local settings: $(getLastError)"

    echo -e "\n==> Wiki backup written to '$hostRoot' <=="

  fi

  if $RESTORE; then

    xIn "$dataFile" docker exec -i "$dataContainer" sh -c "exec mariadb -uroot -p$MARIADB_ROOT_PASSWORD"

    local commandA="tar -cC ${hostRoot}/images ."
    local commandB="docker exec --interactive $viewContainer tar -xC $wikiRoot/images"
    xShow "$commandA | $commandB"
    $commandA | $commandB

    echo && echo "==> Wiki restored from '$hostRoot' <=="

  fi
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  There are no more words.
#
parseCommandLineNew() {
  local args=$(getopt '' $*)
  [ $? -ne 0 ] && usage "syntax error"
  set -- $args
  while :; do # that ':' is bash's NOP. gotta have a NOP.
    case "$1" in
    --)
      shift; break
      ;;
    esac
  done
}
parseCommandLine() {
  set -- $(getOpt "$@")
  while [[ $# -gt 0 ]]; do # https://stackoverflow.com/a/14203146
    case "$1" in
    -b | --backup)
      BACKUP=true
      shift
      ;;
    -D | --data-container)
      dataContainer="$2"
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    --no-decoration)
      DECORATE=false
      shift
      ;;
    -r | --restore)
      RESTORE=true
      shift
      ;;
    -V | --view-container)
      viewContainer="$2"
      shift 2
      ;;
    -v | --verbose)
      QUIET=false
      shift
      ;;
    -w | --work-dir)
      hostRoot="$2"
      shift 2
      dataFile="${hostRoot}/all-databases.sql"
      imageDir="${hostRoot}/images"
      ;;
    -* | --*)
      usage unknown option \"$1\"
      ;;
    *)
      usage "unexpected argument '$1'"
      ;;
    esac
  done
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  You have to say something.
#
usage() {
  if [ -n "$*" ]; then
    echo >&2 -e "\n****  $*  ****"
  fi
  cat >&2 <<EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Backup and restore a DockerWiki.

Options:
  -b | --backup                   Backup database and images
  -D | --data-container  string   Override \$(getContainer data)
  -h | --help                     Print this usage summary
       --no-decoration            Disable composer-naming emulation
  -r | --restore                  Restore database and images
  -V | --view-container  string   Override .env/VIEW_CONTAINER
  -v | --verbose                  Verbose, displays some calculations
  -w | --work-dir  string         Work area, overrides default /tmp area
EOT
  exit 42
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Capua, shall I begin?
#
main "$@"

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Random notes, snippets, old items that we are scared to delete yet.
#
  # # Test getOpt().
  # echo "main: incoming args: (" $(join ', ' "$@") ")"
  # set -- $(getOpt "$@")
  # echo "main: adjusted args: (" $(join ', ' "$@") ")"
  # return

#!/usr/bin/env bash
#
#  Backup and restore tools adapted from hub pages for official
#  mediawiki and mariadb images,

#  This script passes cleartext passwords so is Not Secure.
#  This script requires 'bash' and 'jq'.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/include.sh" # https://stackoverflow.com/a/246128

# What to do.
BACKUP=false
QUIET=true
RESTORE=false

# Where to do it.
WORK_DIR=$(getTempDir)
DATA_FILE="$WORK_DIR/all-databases.sql"
IMAGE_DIR="$WORK_DIR/images"

####-####+####-####+####-####+####-####+
#
#  Validate requested data and view containers.
#
checkContainer() {

  local container=$1 hostName=$2 imageName=$3

  local inspect="docker container inspect X$container"
  local jayQ="jq --raw-output"
  local filter=".[0].Config.Hostname, .[0].Config.Image"
  echo "filter is -${filter}-"

  xShow $inspect '|' $jayQ $filter

  local out=$(xKute $inspect)
  [ $? -ne 0 ] && abend "Error: failed to inspect '$container': $(getLastError)"
  echo "Inspect successful!"
  exit 1

  local json='GOOD DUMP'
  $inspect >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    abend "Error inspecting '$container': $json"
  fi
  echo -e "\nInspection OK? Here's the dump:\n--------------------\n$json"

  # local stuff=$($inspect | $jayQ "$filter" 2>&1)
  # declare -p stuff
  exit 1
  local errFile="$(getTempDir)/stderr"
  local inspect=$($commandA 2>$errFile) # docker $? always zero...
  local error=$(<$errFile)
  [ -n "$error" ] && usage $error

  local hostTest=$(echo "$inspect" | jq --raw-output '.[0].Config.Hostname')
  local imageTest=$(echo "$inspect" | jq --raw-output '.[0].Config.Image')
  # idave2/mariadb:0.2.0 => mariadb
  imageTest=$(echo $(basename $imageTest) | sed -e s/:.*//)

  if [ "$hostTest" != "$hostName" ]; then
    usage "Expected host name '$hostName' for container '$container'; found '$hostTest' instead"
  fi
  if [ "$imageTest" != "$imageName" ]; then
    usage "Expected image name '$imageName' for container '$container'; found '$imageTest' instead"
  fi
}

####-####+####-#'###+####-####+####-####+
#
#  chatgpt://get/quote?keyword="main"&limit=1
#
main() {

  isDockerRunning ||
    abend "This program uses docker which appears to be down; aborting."

  parseCommandLine "$@"

  ! $BACKUP && ! $RESTORE &&
    usage "Please specify --backup or --restore (or both FWIW)"

  mkdir $WORK_DIR $IMAGE_DIR 2>/dev/null

  checkContainer $(getContainer $DW_DATA_SERVICE) $DW_DATA_HOST mariadb
  checkContainer $(getContainer $DW_VIEW_SERVICE) $DW_VIEW_HOST mediawiki

  if ! $QUIET; then
    echo
    echo "DATA_CONTAINER = '$DATA_CONTAINER'"
    echo "VIEW_CONTAINER = '$VIEW_CONTAINER'"
    echo "WORK_DIR = '$WORK_DIR'"
    echo "DATA_FILE = '$DATA_FILE'"
    echo "IMAGE_DIR = '$IMAGE_DIR'"
  fi

  echo && echo SKIPPING BACKUP/RESTORE TILL DAVE TESTS ~/.DOCKERWIKI/.ENV && return 1

  if $BACKUP; then

    xOut "$DATA_FILE" docker exec "$DATA_CONTAINER" sh -c "mariadb-dump --all-databases -uroot -p$MARIADB_ROOT_PASSWORD"

    local commandA="docker exec $VIEW_CONTAINER tar -cC /var/www/html/images ."
    local commandB="tar -xC ${WORK_DIR}/images"
    xShow "$commandA | $commandB"
    $commandA | $commandB

    echo && echo "Wiki backup written to '$WORK_DIR'"

  fi

  if $RESTORE; then

    xIn "$DATA_FILE" docker exec -i "$DATA_CONTAINER" sh -c "exec mariadb -uroot -p$MARIADB_ROOT_PASSWORD"

    local commandA="tar -cC ${WORK_DIR}/images ."
    local commandB="docker exec --interactive $VIEW_CONTAINER tar -xC /var/www/html/images"
    xShow "$commandA | $commandB"
    $commandA | $commandB

    echo && echo "Wiki restored from '$WORK_DIR'"

  fi
}

####-####+####-####+####-####+####-####+
#
#  There are no more words.
#
parseCommandLine() {
  # https://stackoverflow.com/a/14203146
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -b | --backup)
      BACKUP=true
      shift
      ;;
    -d | --data-container)
      DATA_CONTAINER="$2"
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
    -v | --view-container)
      VIEW_CONTAINER="$2"
      shift 2
      ;;
    -w | --work-dir)
      WORK_DIR="$2"
      shift 2
      DATA_FILE="${WORK_DIR}/all-databases.sql"
      IMAGE_DIR="${WORK_DIR}/images"
      ;;
    -x | --xerbose)
      QUIET=false
      shift
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

####-####+####-####+####-####+####-####+
#
#  You have to say something.
#
usage() {
  if [ -n "$*" ]; then
    echo && echo "****  $*  ****"
  fi
  cat <<-EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Backup and restore a DockerWiki.

Options:
  -b | --backup                   Backup database and images
  -d | --data-container  string   Override .env/DATA_CONTAINER
  -h | --help                     Print this usage summary
       --no-decoration            Disable composer-naming emulation
  -r | --restore                  Restore database and images
  -v | --view-container  string   Override .env/VIEW_CONTAINER
  -w | --work-dir  string         Work area, overrides .env/TEMP_DIR
  -x | --xerbose                  Verbose (sorry, -v was taken)
EOT
  exit 42
}

####-####+####-####+####-####+####-####+
#
#  Capua, shall I begin?
#
main "$@"

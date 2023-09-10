#!/usr/bin/env bash
#
#  Ideas for data backup and restore.
#  Also see https://hub.docker.com/_/mariadb.
#  This script passes cleartext passwords so is Not Secure.
#  This script requires 'bash' and 'jq'.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# https://stackoverflow.com/a/246128
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "${SCRIPT_DIR}/include.sh"
source "${SCRIPT_DIR}/../.env"
source "${USER_CONFIG}" 2>/dev/null

# What to do.
BACKUP=false
QUIET=true
RESTORE=false

# Where to do it.
WORK_DIR=${TEMP_DIR}
DATA_FILE="${WORK_DIR}/all-databases.sql"
IMAGE_DIR="${WORK_DIR}/images"

# Constants.
DATA_IMAGE_NAME() { echo mariadb; }
VIEW_IMAGE_NAME() { echo mediawiki; }

####-####+####-####+####-####+####-####+
#
#  Validate requested data and view containers.
#
checkContainer() {

  local container=$1 hostName=$2 imageName=$3

  local commandA="docker container inspect $container"
  local commandB="jq --raw-output '.[0].Config.Hostname, .[0].Config.Image'"
  xShow $commandA '|' $commandB

  local errFile="${TEMP_DIR}/stderr"
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

  parseCommandLine "$@"

  ! $BACKUP && ! $RESTORE &&
    usage "Please specify --backup or --restore (or both FWIW)"

  mkdir $WORK_DIR $IMAGE_DIR 2>/dev/null

  checkContainer "$DATA_CONTAINER" "$DATA_HOST" $(DATA_IMAGE_NAME)
  checkContainer "$VIEW_CONTAINER" "$VIEW_HOST" $(VIEW_IMAGE_NAME)

  if ! $QUIET; then
    echo
    echo "DATA_CONTAINER = '$DATA_CONTAINER'"
    echo "VIEW_CONTAINER = '$VIEW_CONTAINER'"
    echo "WORK_DIR = '$WORK_DIR'"
    echo "DATA_FILE = '$DATA_FILE'"
    echo "IMAGE_DIR = '$IMAGE_DIR'"
  fi

echo && echo SKIPPING BACKUP/RESTORE TILL DAVE TESTS  ~/.DOCKERWIKI/.ENV && return 1

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

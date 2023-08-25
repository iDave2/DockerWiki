#!/usr/bin/env bash
#
#  Ideas for data backup and restore.
#  Also see https://hub.docker.com/_/mariadb.
#  This script passes cleartext passwords so is Not Secure.
#  This script requires bash and the ever useful jq.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# https://stackoverflow.com/a/246128
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "${SCRIPT_DIR}/include.sh"
source "${SCRIPT_DIR}/../.env"

# What are we even doing here?
BACKUP=false
RESTORE=false

# Where to backup to or restore from.
WORK_DIR=${BACKUP_DIR}
DATA_FILE="${WORK_DIR}/all-databases.sql"
IMAGE_DIR="${WORK_DIR}/images"

# Constants used to validate incoming data and view container names.
DATA_HOST_NAME() { echo data; }
DATA_IMAGE_NAME() { echo mariadb; } # Actually $DID/mariadb, see below.
VIEW_HOST_NAME() { echo view; }
VIEW_IMAGE_NAME() { echo mediawiki; }

# [ mariadb == $(DATA_IMAGE_NAME) ] && echo Match || echo No Match
# exit 2

####-####+####-####+####-####+####-####+
#
#  Check validity of requested data and view containers.
#
checkContainer() {

  local container=$1 hostName=$2 imageName=$3

  local commandA="docker container inspect $container"
  local commandB="jq --raw-output '.[0].Config.Hostname, .[0].Config.Image'"
  xShow $commandA '|' $commandB

  local errFile='/tmp/stderr'
  local inspect=$($commandA 2>$errFile) # docker $? always zero...
  local error=$(<$errFile)
  [ -n "$error" ] && usage $error

  local hostTest=$(echo "$inspect" | jq --raw-output '.[0].Config.Hostname')
  local imageTest=$(echo "$inspect" | jq --raw-output '.[0].Config.Image')
  # remove $DID at front and :tag at end
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
#  chatgpt://sound/play/quote?key="main"&limit=1
#
main() {

  parseCommandLine "$@"

  ! $BACKUP && ! $RESTORE &&
    usage Please specify --backup or --restore \(or both FWIW\)

  # Are containers fairly valid?
  checkContainer ${DATA_CONTAINER} $(DATA_HOST_NAME) $(DATA_IMAGE_NAME)
  checkContainer ${VIEW_CONTAINER} $(VIEW_HOST_NAME) $(VIEW_IMAGE_NAME)
  return 99
  local command="docker container inspect '$DATA_CONTAINER' | jq '.[0].Config.Env' | grep MARIADB_DATABASE"
  xShow $command
  local dbName=$(eval $command)
  echo $dbName
  if [[ "$dbName" == *mediawiki* ]]; then
    echo && echo "# Using data container '$DATA_CONTAINER'"
  else
    usage "Expected to find 'mediawiki' database in data container '$DATA_CONTAINER'; found '$dbName' instead"
    return -17
  fi

  return 42

  # Is view container compelling? https://stackoverflow.com/a/12973694
  command="docker container inspect '$VIEW_CONTAINER' | jq '.[0].Config.Env' | grep MEDIAWIKI_VERSION | xargs"
  xShow $command
  local version=$(eval $command)
  echo $version
  if [ -n "$version" ]; then
    echo && echo "# Using data container '$DATA_CONTAINER'"
  else
    usage "Expected to find MEDIAWIKI_VERSION in view container '$VIEW_CONTAINER'; found '$version' instead"
    return -18
  fi

  # [ -d "$WORK_DIR" ] || mkdir "$BACKUP_DIR"
  # [ -d "$IMAGE_DIR"] || mkdir "$IMAGE_DIR"

  echo "DATA_CONTAINER = '$DATA_CONTAINER'"
  echo "VIEW_CONTAINER = '$VIEW_CONTAINER'"
  echo "WORK_DIR = '$WORK_DIR'"
  echo "DATA_FILE = '$DATA_FILE'"
  echo "IMAGE_DIR = '$IMAGE_DIR'"

  return 42

  # Backup and restore.
  if $BACKUP; then
    xOut "$DATA_FILE" docker exec "$CONTAINER" sh -c "mariadb-dump --all-databases -uroot -p$MARIADB_ROOT_PASSWORD"
    local command="docker run --rm ${VIEW_CONTAINER} tar -cC /var/www/html/images . | tar -xC ${BACKUP_DIR}/images"
    xShow $command
  fi
  if $RESTORE; then
    xIn "$DATA_FILE" docker exec -i "$CONTAINER" sh -c "exec mariadb -uroot -p$MARIADB_ROOT_PASSWORD"
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
#  Print a usage summary and exit.
#
usage() {
  if [ -n "$*" ]; then
    echo && echo "==> $*"
  fi
  cat <<-EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Backup and restore a MariaDB database.

Options:
  -b | --backup                   Backup database and images
  -d | --data-container  string   Data container, overrides .env
  -h | --help                     Print this usage summary
  -r | --restore                  Restore database and images
  -v | --view-container  string   View container, overrides .env
  -w | --work-dir  string         Work area, overrides .env/BACKUP_DIR
EOT
  exit 42
}

main "$@"

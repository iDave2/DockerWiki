#!/usr/bin/env bash
#
#  Ideas for data backup and restore.
#  Also see https://hub.docker.com/_/mariadb.
#  This script passes cleartext passwords so is Not Secure.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# https://stackoverflow.com/a/246128
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "${SCRIPT_DIR}/include.sh"
source "${SCRIPT_DIR}/../.env"

BACKUP=false
RESTORE=false

WORK_DIR=${BACKUP_DIR}
DATA_FILE="${WORK_DIR}/all-databases.sql"
IMAGE_DIR="${WORK_DIR}/images"

main() {

  # echo '"$@"' = \"$(join '" "' "$@")\"

  # Parse command line, https://stackoverflow.com/a/14203146.

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
      return 1
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
      return 41
      ;;
    *)
      usage "unexpected argument '$1'"
      return 42
      ;;
    esac
  done

  # [ -d "$WORK_DIR" ] || mkdir "$BACKUP_DIR"
  # [ -d "$IMAGE_DIR"] || mkdir "$IMAGE_DIR"

  echo "DATA_CONTAINER = '$DATA_CONTAINER'"
  echo "VIEW_CONTAINER = '$VIEW_CONTAINER'"
  echo "WORK_DIR = '$WORK_DIR'"
  echo "DATA_FILE = '$DATA_FILE'"
  echo "IMAGE_DIR = '$IMAGE_DIR'"

  # echo backup[$BACKUP], restore[$RESTORE], file[$DATA_FILE], containers[\"$(join '" "' "${CONTAINERS[@]}")\"]

  if ! $BACKUP && ! $RESTORE; then
    usage Specify --backup or --restore \(or both FWIW\)
    return $?
  fi

  case ${#CONTAINERS[@]} in
  0)
    usage Please specify a DATABASE_CONTAINER
    return 41
    ;;
  1)
    CONTAINER=${CONTAINERS[0]}
    ;;
  *)
    usage Expected one container, found \"$(join '" "' "${CONTAINERS[@]}")\"
    return $?
    ;;
  esac

  # echo backup[$BACKUP], restore[$RESTORE], file[$DATA_FILE], container[$CONTAINER]

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

usage() {
  if [ -n "$*" ]; then
    echo && echo "** $*"
  fi
  cat <<-EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS] DATABASE_CONTAINER

Backup and restore a MariaDB database.

Options:
  -b | --backup                   Backup database and images
  -d | --data-container  string   Data container, overrides .env
  -h | --help                     Print this usage summary
  -r | --restore                  Restore database and images
  -v | --view-container  string   View container, overrides .env
  -w | --work-dir  string         Work area, overrides .env/BACKUP_DIR
EOT
  return 42
}

main "$@"

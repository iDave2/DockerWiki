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
CONTAINER=
FILE=$BACKUP_FILE
RESTORE=false

main() {

  # echo '"$@"' = \"$(join '" "' "$@")\"

  # Parse command line, https://stackoverflow.com/a/14203146.

  CONTAINERS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -b | --backup)
      BACKUP=true
      shift
      ;;
    -f | --file)
      FILE="$2"
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
    -* | --*)
      usage unknown option \"$1\"
      return 41
      ;;
    *)
      CONTAINERS+=("$1")
      shift
      ;;
    esac
  done

  # echo backup[$BACKUP], restore[$RESTORE], file[$FILE], containers[\"$(join '" "' "${CONTAINERS[@]}")\"]

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

  # echo backup[$BACKUP], restore[$RESTORE], file[$FILE], container[$CONTAINER]

  # Backup and restore.
  if $BACKUP; then
    xOut "$FILE" docker exec "$CONTAINER" sh -c "mariadb-dump --all-databases -uroot -p$MARIADB_ROOT_PASSWORD"
  fi
  if $RESTORE; then
    xIn "$FILE" docker exec -i "$CONTAINER" sh -c "exec mariadb -uroot -p$MARIADB_ROOT_PASSWORD"
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
  -b | --backup         Backup a database
  -f | --file  string   File to backup to or restore from
  -h | --help           Print this usage summary
  -r | --restore        Restore a database
EOT
  return 42
}

main "$@"

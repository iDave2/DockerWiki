#!/usr/bin/env bash
#
#  Something to build and run things (over and over and).
#
#  This only builds Dockerfiles. Use compose.yaml for music.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# https://stackoverflow.com/a/246128

ENV_FILE="${SCRIPT_DIR}/../.env"
ENV_DATA="${SCRIPT_DIR}/../.envData"

source ${SCRIPT_DIR}/include.sh
source "$ENV_FILE"
source "$USER_CONFIG" 2>/dev/null

# Basename of working directory determines what is built:
# mariadb, mediawiki, or both.
WHAT=$(basename $(pwd -P))

# Command-line options.
CLEAN=false
DECORATE=true
INTERACTIVE=false
KLEAN=false

# Build options.
CACHE=1 # meaning cache data build, not view build
BUILD_OPTIONS=''

# Container / runtime configuration.
CONTAINER=
ENVIRONMENT=
HOST=
IMAGE=
MOUNT=
PUBLISH=

# These names are initialized in main().
DATA_VOLUME= # database volume name
DATA_TARGET= # database volume mountpoint inside container
NETWORK=     # network name for container chatter

main() {

  parseCommandLine "$@"

  # Finish initializing parameters.
  DATA_VOLUME=$(rename "$DW_DATA_VOLUME" "$DW_PROJECT" 'volume')
  DATA_TARGET=/var/lib/mysql
  NETWORK=$(rename "$DW_NETWORK" "$DW_PROJECT" 'network')

  # Make one or both services.
  case $WHAT in
  mariadb) makeData ;;
  mediawiki) makeView ;;
  *)
    if [ -f compose.yaml -a -d mariadb -a -d mediawiki ]; then
      if $CLEAN || $KLEAN; then
        cd mediawiki && makeView && cd ..
        cd mariadb && makeData && cd ..
      else
        cd mariadb && makeData && cd ..
        cd mediawiki && makeView && cd ..
      fi
    else
      usage Expected \$PWD in mariadb, mediawiki, or their parent folder, not \"$WHAT\".
    fi
    ;;
  esac
}

make() {

  # Remove any existing CONTAINER.
  xCute docker container ls --all --filter name=$CONTAINER
  if [[ $? && ${#LINES[@]} > 1 ]]; then # ignore sticky column headers
    xCute docker stop $CONTAINER
    xCute docker rm $CONTAINER
  fi

  # Remove any existing IMAGE(s).
  xCute docker image ls $IMAGE
  if [[ $? && ${#LINES[@]} > 1 ]]; then
    local images=()
    for ((i = 1; i < ${#LINES[@]}; ++i)); do
      images+=($IMAGE:$(echo ${LINES[i]} | cut -f 2 -w))
    done # https://stackoverflow.com/a/1951523
    xCute docker rmi "${images[@]}"
  fi

  # Remove volumes and networks if requested.
  if $KLEAN; then
    xCute docker volume ls --filter name=$DATA_VOLUME
    if [[ $? && ${#LINES[@]} = 2 ]]; then
      xCute docker volume rm $DATA_VOLUME
    fi
    xCute docker network ls --filter name=$NETWORK
    if [[ $? && ${#LINES[@]} = 2 ]]; then
      xCute docker network rm $NETWORK
    fi
  fi

  # Stop here if user only wants to clean up.
  if $CLEAN || $KLEAN; then
    return 0
  fi

  # Create a docker volume for the database and a network for chit chat.
  xCute docker volume ls --filter name=$DATA_VOLUME
  if [[ ! $? || ${#LINES[@]} < 2 ]]; then
    xCute docker volume create $DATA_VOLUME
  fi
  xCute docker network ls --filter name=$NETWORK
  if [[ ! $? || ${#LINES[@]} < 2 ]]; then
    xCute docker network create $NETWORK
  fi

  # Rebuild and rerun. Over and over and.
  xCute docker build $BUILD_OPTIONS $(eval echo "'--tag $IMAGE:'"{$TAGS}) .
  if $INTERACTIVE; then # --interactive needs work...
    xCute docker run $ENVIRONMENT --interactive --rm --tty \
      --network $NETWORK --name $CONTAINER --hostname $HOST \
      --network-alias $HOST $MOUNT $PUBLISH $IMAGE
  else
    xCute docker run --detach $ENVIRONMENT --network $NETWORK \
      --name $CONTAINER --hostname $HOST --network-alias $HOST \
      $MOUNT $PUBLISH $IMAGE
  fi
}

makeData() {
  [ $CACHE -lt 1 ] && BUILD_OPTIONS='--no-cache' || BUILD_OPTIONS=''
  local options=(
    MARIADB_ROOT_PASSWORD_HASH $DW_DB_ROOT_PASSWORD_HASH
    MARIADB_DATABASE $DW_DB_DATABASE
    MARIADB_USER $DW_DB_USER
    MARIADB_PASSWORD_HASH $DW_DB_PASSWORD_HASH
  )
  for (( i = 0; $i < ${#options[*]}; i += 2 )); do
    BUILD_OPTIONS+=" --build-arg ${options[$i]}=${options[$i+1]}"
  done

  CONTAINER=$(rename "$DW_DATA_SERVICE" "$DW_PROJECT" 'container')
  # ENVIRONMENT="--env-file $ENV_DATA"
  HOST=$DW_DATA_HOST
  IMAGE=$DW_DID/mariadb
  MOUNT="--mount type=volume,src=$DATA_VOLUME,dst=$DATA_TARGET"
  PUBLISH=

  make
}

makeView() {
  [ $CACHE -lt 2 ] && BUILD_OPTIONS='--no-cache' || BUILD_OPTIONS=''
  local options=(
    MW_DB_DATABASE $DW_DB_DATABASE
    MW_DB_USER $DW_DB_USER
    MW_DB_PASSWORD $DW_DB_PASSWORD
  )
  for (( i = 0; $i < ${#options[*]}; i += 2 )); do
    BUILD_OPTIONS+=" --build-arg ${options[$i]}=${options[$i+1]}"
  done
  # BUILD_OPTIONS+=" --build-arg MW_DB_DATABASE=$DW_DB_DATABASE"
  # BUILD_OPTIONS+=" --build-arg MW_DB_USER=$DW_DB_USER"

  CONTAINER=$(rename "$DW_VIEW_SERVICE" "$DW_PROJECT" 'container')
  ENVIRONMENT=
  HOST=$DW_VIEW_HOST
  IMAGE=$DW_DID/mediawiki
  MOUNT=
  PUBLISH="--publish $DW_PORTS"

  make
}

parseCommandLine() {
  for arg; do
    case "$arg" in
    --cache)
      CACHE=2 # cache both builds
      ;;
    -c | --clean)
      CLEAN=true
      ;;
    -h | --help)
      usage
      ;;
    -i | --interactive)
      INTERACTIVE=true
      ;;
    -k | --klean)
      KLEAN=true
      ;;
    --no-cache)
      CACHE=0 # cache no build
      ;;
    --no-decoration)
      DECORATE=false
      ;;
    *)
      usage unexpected command line token \"$arg\"
      ;;
    esac
  done
}

rename() {
  if $DECORATE; then
    echo $(decorate "$@")
  else
    echo "$1"
  fi
}

usage() {
  if [ -n "$*" ]; then
    echo && echo "** $*"
  fi
  cat <<-EOT

Usage: $(basename ${BASH_SOURCE[0]}) [BUILD_OPTIONS]

Build and run this project using Docker files.

Options:
       --cache           Enable cache for all builds (2)
  -c | --clean           Remove built artifacts
  -i | --interactive     Run interactively (1)
  -h | --help            Print this usage summary
  -k | --klean           --clean plus remove volumes and network!
       --no-cache        Disable cache for all builds (2)
       --no-decoration   Disable composer-naming emulation

Notes:
  1. "run -it" is out of order; STDOUT goes to Tahiti.
  2. By default, data build is cached, view build is not (to avoid
     caching secret key). Use --cache or --no-cache to override.
EOT
  exit 1
}

main "$@"

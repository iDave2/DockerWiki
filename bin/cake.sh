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
HERE=$(basename $(pwd -P))

# Command-line options.
CLEAN=false
DECORATE=true
INTERACTIVE=false
KLEAN=false
NO_CACHE=false

# Build options.
OPTIONS=

# Container / runtime configuration.
CONTAINER=
ENVIRONMENT=
HOST=
IMAGE=
MOUNT=
PUBLISH=

# These names are decorated in main().
DATA_VOLUME=
DATA_TARGET=/var/lib/mysql
NETWORK=

main() {

  # Parse command line.
  for arg; do
    case "$arg" in
    -c | --clean) CLEAN=true ;;
    -h | --help)
      usage
      return 1
      ;;
    -i | --interactive) INTERACTIVE=true ;;
    -k | --klean) KLEAN=true ;;
    --no-cache) NO_CACHE=true ;;
    --no-decoration) DECORATE=false ;;
    *)
      usage unexpected command line token \"$arg\"
      return $?
      ;;
    esac
  done

  # Finish initializing parameters.
  DATA_VOLUME=$(rename "$DW_DATA_VOLUME" "$DW_PROJECT" 'volume')
  DATA_TARGET=/var/lib/mysql
  NETWORK=$(rename "$DW_NETWORK" "$DW_PROJECT" 'network')

  # Make one or both services.
  case $HERE in
  mariadb) makeData ;;
  mediawiki) makeView ;;
  *)
    if [ -f compose.yaml -a -d mariadb -a -d mediawiki ]; then
      cd mariadb && makeData && cd ..
      cd mediawiki && makeView && cd ..
    else
      usage Expected \$PWD in mariadb, mediawiki, or their parent folder, not \"$HERE\".
      return 1
    fi
    ;;
  esac
}

make() {

  # OPTIONS is the same for any container.
  $NO_CACHE && OPTIONS='--no-cache'

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
    xOut "/dev/null" docker rmi "${images[@]}"
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
  xCute docker build $OPTIONS $(eval echo "'--tag $IMAGE:'"{$TAGS}) .
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
  CONTAINER=$(rename "$DW_DATA_SERVICE" "$DW_PROJECT" 'container')
  ENVIRONMENT="--env-file $ENV_DATA"
  HOST=$DW_DATA_HOST
  IMAGE=$DID/mariadb
  MOUNT="--mount type=volume,src=$DATA_VOLUME,dst=$DATA_TARGET"
  PUBLISH=
  make
}

makeView() {
  CONTAINER=$(rename "$DW_VIEW_SERVICE" "$DW_PROJECT" 'container')
  ENVIRONMENT=
  HOST=$DW_VIEW_HOST
  IMAGE=$DID/mediawiki
  MOUNT=
  PUBLISH="--publish $DW_PORTS"
  make
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

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Build and run this project using Docker files.

Options:
  -c | --clean           Remove built artifacts
  -i | --interactive     Run interactively (run -it)
  -h | --help            Print this usage summary
  -k | --klean           --clean plus remove volumes and network!
       --no-cache        Disable cache during builds
       --no-decoration   Disable composer-naming emulation

Note: --interactive is out of order; STDOUT goes to Tahiti.
EOT
  return 1
}

main "$@"

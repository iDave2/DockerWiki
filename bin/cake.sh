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

# Simulate composer-generated names for volume 'data' and network 'net'
# so we don't need to keep switching when changing builds.
DATA_VOLUME=wiki_${DATA_VOLUME}
DATA_TARGET=/var/lib/mysql
NETWORK=wiki_${NETWORK}

# Continue with Docker file build(s).
CLEAN=false
CONTAINER=
ENVIRONMENT=
HERE=$(basename $(pwd -P))
HOST_NAME=
IMAGE=
INTERACTIVE=false
KLEAN=false
MOUNT=
NO_CACHE=false
OPTIONS=
PUBLISH=

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
    -n | --no-cache) NO_CACHE=true ;;
    *)
      usage unexpected command line token \"$arg\"
      return $?
      ;;
    esac
  done

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

  # Remove any existing IMAGE.
  xCute docker image ls $IMAGE
  if [[ $? && ${#LINES[@]} > 1 ]]; then
    xOut "/dev/null" docker rmi $(eval echo "$IMAGE:"{$TAGS})
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
      --network $NETWORK --name $CONTAINER --hostname $HOST_NAME \
      --network-alias $HOST_NAME $MOUNT $PUBLISH $IMAGE
  else
    xCute docker run --detach $ENVIRONMENT --network $NETWORK \
      --name $CONTAINER --hostname $HOST_NAME --network-alias $HOST_NAME \
      $MOUNT $PUBLISH $IMAGE
  fi
}

makeData() {
  CONTAINER=$DATA_CONTAINER
  ENVIRONMENT="--env-file $ENV_DATA"
  HOST_NAME=$DATA_HOST_NAME
  IMAGE=$DID/mariadb
  MOUNT="--mount type=volume,src=$DATA_VOLUME,dst=$DATA_TARGET"
  PUBLISH=
  make
}

makeView() {
  CONTAINER=$VIEW_CONTAINER
  ENVIRONMENT=
  HOST_NAME=$VIEW_HOST_NAME
  IMAGE=$DID/mediawiki
  MOUNT=
  PUBLISH="--publish $PORTS"
  make
}

usage() {
  if [ -n "$*" ]; then
    echo && echo "** $*"
  fi
  cat <<-EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Build and run this project using Docker files.

Options:
  -c | --clean        Remove built artifacts
  -i | --interactive  Run interactively (run -it)
  -h | --help         Print this usage summary
  -k | --klean        --clean plus remove volumes and network!
  -n | --no-cache     Disable cache during builds

Note: --interactive is out of order; STDOUT goes to Tahiti.
EOT
  return 1
}

main "$@"

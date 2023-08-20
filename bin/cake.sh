#!/usr/bin/env bash
#
#  Something to build and run things (over and over and).
#
#  This only builds Dockerfiles. Use compose.yaml for music.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

SCRIPT_DIR=$(dirname $(realpath $0)) # https://stackoverflow.com/a/246128
source $SCRIPT_DIR/include.sh

ENV_FILE="$SCRIPT_DIR/.env"
source $ENV_FILE

# Simulate composer-generated names for volume 'data' and network 'net'
# so we don't need to keep switching when changing builds.
DATA_VOLUME=wiki_data
DATA_TARGET=/var/lib/mysql
# DOCS_VOLUME=wiki_docs  # Temporary, for debugging php
# DOCS_TARGET=/var/www/html # Temporary, for debugging php
NETWORK=wiki_net

# Continue with Docker file build(s).
CLEAN=false
CONTAINER=
HERE=$(basename $(pwd -P))
IMAGE=
INTERACTIVE=false
KLEAN=false
MOUNT=
PUBLISH=

main() {

  # Parse command line.
  for arg; do
    case "$arg" in
    -c | --clean) CLEAN=true ;;
    -h | --help) usage; return 1 ;;
    -i | --interactive) INTERACTIVE=true ;;
    -k | --klean) KLEAN=true ;;
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
      usage Expected \$PWD in mariadb, mediawiki, or their parent, not \"$HERE\".
      return 1
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

  # Remove any existing IMAGE.
  xCute docker image ls $IMAGE
  if [[ $? && ${#LINES[@]} > 1 ]]; then
    xCute docker rmi $(eval echo "$IMAGE:"{$TAGS})
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
  xCute docker build $(eval echo "'--tag $IMAGE:'"{$TAGS}) .
  if $INTERACTIVE; then # --interactive needs work...
    xCute docker run --env-file $ENV_FILE --interactive --rm --tty --network $NETWORK \
      --name $CONTAINER --hostname $CONTAINER --network-alias $CONTAINER $MOUNT $PUBLISH $IMAGE
  else
    xCute docker run --detach --env-file $ENV_FILE $PUBLISH --network $NETWORK \
      $(echo --{name,hostname,network-alias}" $CONTAINER") $MOUNT $IMAGE
  fi
}

makeData() {
  CONTAINER=data
  IMAGE=$DID/mariadb
  MOUNT="--mount type=volume,src=$DATA_VOLUME,dst=$DATA_TARGET"
  PUBLISH=
  make
}

makeView() {
  CONTAINER=view
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

Usage: $0 [OPTIONS]

Build and run this project using Docker files.

Options:
  -c | --clean        Remove built artifacts
  -i | --interactive  Run interactively (run -it)
  -h | --help         Print this usage summary
  -k | --klean        --clean plus remove volumes and network!

Note: --interactive is out of order; STDOUT goes to Tahiti.
EOT
  return 1
}

main "$@"

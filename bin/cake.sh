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
WHERE=$(basename $(pwd -P))

# Command-line options.
CLEAN=false
DECORATE=true
INTERACTIVE=false
KLEAN=false
MAKING_BOTH=false # making both data and view or just one of them?

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Build options.
#
#  The funny $CACHE processing could be removed since we no longer
#  generate '$wgSecretKey' in Dockerfile so no longer need to worry
#  about it being cached into a constant. The idea was,
#
#    $CACHE=0  # --no-cache, disable cache for both data and view
#    $CACHE=1  # default, cache data, don't cache view builds
#    $CACHE=2  # --cache, cache both builds
#
# CACHE=1 # meaning cache data build, not view build
CACHE=2
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

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Function returns requested container name given 'data' or 'view' as
#  input. E.g., 'data' => 'wiki-data-1' unless --no-decoration.
#
getContainer() {
  local service
  case "$1" in
  data)
    service="$DW_DATA_SERVICE"
    ;;
  view)
    service="$DW_VIEW_SERVICE"
    ;;
  *)
    usage "getContainer: expected 'data' or 'view', not '$1'"
    ;;
  esac
  echo $(rename "$service" "$DW_PROJECT" 'container')
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Yet another entry point.
#
main() {

  isDockerRunning ||
    abend "This program uses docker which appears to be down; aborting."

  parseCommandLine "$@"

  # Finish initializing parameters.
  DATA_VOLUME=$(rename "$DW_DATA_VOLUME" "$DW_PROJECT" 'volume')
  DATA_TARGET=/var/lib/mysql
  NETWORK=$(rename "$DW_NETWORK" "$DW_PROJECT" 'network')

  # Make one or both services.
  case $WHERE in
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
      usage Expected \$PWD in mariadb, mediawiki, or their parent folder, not \"$WHERE\".
    fi
    ;;
  esac
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Create or destroy an image and its container.
#
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

  # Build the image.
  xCute docker build $BUILD_OPTIONS $(eval echo "'--tag $IMAGE:'"{$TAGS}) .

  # Launch container with new image.
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

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mariadb image.
#
makeData() {

  [ $CACHE -lt 1 ] && BUILD_OPTIONS='--no-cache' || BUILD_OPTIONS=''

  local options=(
    MARIADB_ROOT_PASSWORD_HASH "$DW_DB_ROOT_PASSWORD_HASH"
    MARIADB_DATABASE "$DW_DB_DATABASE"
    MARIADB_USER "$DW_DB_USER"
    MARIADB_PASSWORD_HASH "$DW_DB_PASSWORD_HASH"
  )
  for ((i = 0; $i < ${#options[*]}; i += 2)); do
    BUILD_OPTIONS+=" --build-arg ${options[$i]}=${options[$i + 1]}"
  done

  CONTAINER=$(getContainer data)
  HOST=$DW_DATA_HOST
  IMAGE=$DW_DID/mariadb
  MOUNT="--mount type=volume,src=$DATA_VOLUME,dst=$DATA_TARGET"
  PUBLISH=

  make

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mediawiki image.
#
makeView() {

  [ $CACHE -lt 2 ] && BUILD_OPTIONS='--no-cache' || BUILD_OPTIONS=''

  local options=(
    MW_ADMINISTRATOR "$DW_MW_ADMINISTRATOR"
    MW_PASSWORD "$DW_MW_PASSWORD"
    MW_DB_DATABASE "$DW_DB_DATABASE"
    MW_DB_USER "$DW_DB_USER"
    MW_DB_PASSWORD "$DW_DB_PASSWORD"
  )
  for ((i = 0; $i < ${#options[*]}; i += 2)); do
    BUILD_OPTIONS+=" --build-arg ${options[$i]}=${options[$i + 1]}"
  done

  CONTAINER=$(getContainer view)
  ENVIRONMENT=
  HOST=$DW_VIEW_HOST
  IMAGE=$DW_DID/mediawiki
  MOUNT=
  PUBLISH="--publish $DW_MW_PORTS"

  make

  # No need to configure mediawiki if tearing everything down.
  ($CLEAN || $KLEAN) && return 0

  # Database needs to be Running for maintenance/install.php to work.
  waitForData
  if [ $? -ne 0 ]; then
    usage Data container unavailable, cannot initialize mediawiki, aborting
  fi

  # Install (aka configure, setup) mediawiki now that we have a mariadb
  # network. This generates the famous LocalSettings.php file in docroot.
  xCute docker exec $CONTAINER maintenance/run CommandLineInstaller \
    --dbtype=mysql --dbserver=data --dbname=mediawiki --dbuser=wikiDBA \
    --dbpassfile='DockerWiki/dbpassfile' --passfile='DockerWiki/passfile' \
    --scriptpath='' --server='http://localhost:8080' DockerWiki WikiAdmin
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  TODO: Add a helpful comment here.
#
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

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Emulate docker compose name decoration? 'view' => 'wiki-view-1'?
#
rename() {
  if $DECORATE; then
    echo $(decorate "$@")
  else
    echo "$1"
  fi
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Print usage summary when '--help' requested or program aborts.
#
usage() {
  if [ -n "$*" ]; then
    echo && echo "***  $*"
  fi
  cat <<-EOT

Usage: $(basename ${BASH_SOURCE[0]}) [BUILD_OPTIONS]

Build and run this project using Docker files.

Options:
       --cache           Enable cache for all builds
  -c | --clean           Remove built artifacts
  -i | --interactive     Run interactively (1)
  -h | --help            Print this usage summary
  -k | --klean           --clean plus remove volumes and network!
       --no-cache        Disable cache for all builds
       --no-decoration   Disable composer-naming emulation

Notes:
  1. "run -it" is out of order; STDOUT goes to Tahiti.
  2. Default used to be "cache data build, not view build" so we ...
    Dave, just remove all this noise, may it  be forgotten...
  By default, data build is cached, view build is not (to avoid
     caching secret key). Use --cache or --no-cache to override.
EOT
  exit 1
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  This emulates a "view depends_on data" when creating things without
#  the help of docker compose (i.e., when running this script).
#
#  From 'docker ps' dockumentation circa 2023, container status can be one
#  of created, restarting, running, removing, paused, exited, or dead.
#  https://docs.docker.com/engine/reference/commandline/ps/
#
#  If database is not Running, the wiki container will be left with no
#  LocalSettings.php and user will see the initialization wizard rather
#  than a working DockerWiki.
#
#  Also see https://docs.docker.com/config/formatting/.
#
waitForData() {

  local dataContainer=$(getContainer data) dataState
  local viewContainer=$(getContainer view) viewState
  local inspect='docker inspect --format' goville='{{json .State.Running}}'

  # Show user what we think is happening.
  xShow $inspect \"$goville\" $dataContainer

  # dataState=$(echo $($inspect "$goville" $dataContainer 2>&1))
  # [ "${dataState:0:1}" == \" ] || dataState=\"$dataState\"
  # echo Initial data container state is $dataState

  # Even though data container status immediately shows "running",
  # MediaWiki installer fails unless we explicitly rest a bit.
  # "A bit" is four seconds on my laptop, perhaps there is another
  # inspection that works better than .State.Status...
  # sleep 5

  # Wait for data container to be Running.
  # The extra 'echo's
  # remove confusing whitespace from stderr results.
  # sleep 4 # not working...
  for ((i = 0; i < 5; ++i)); do

    local golom='{{json .NetworkSettings.Networks.wiki_net.IPAddress}}'
    echo && echo '####-####+####-####+'
    xShow $inspect "$golom" $dataContainer
    $inspect "$golom" $dataContainer

    dataState=$(echo $($inspect "$goville" $dataContainer 2>&1))
    [ "${dataState:0:1}" == \" ] || dataState=\"$dataState\"

    viewState=$(echo $($inspect "$goville" $viewContainer 2>&1))
    [ "${viewState:0:1}" == \" ] || viewState=\"$viewState\"

    echo "Container status: data is $dataState, view is $viewState"

    [ "$dataState" == '"true"' ] && return 0 || sleep 1

  done
  return 1 # nonzero $? indicates failure
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Piece of cake? Maybe in retrospect. ;)
#
main "$@"

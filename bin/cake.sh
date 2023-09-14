#!/usr/bin/env bash
#
#  Something to build and run things:
#
#    $ ./cake.sh     # create everything
#    $ ./cake.sh -k  # destroy everything
#    $ ./cake.sh -h  # print usage summary
#
#  When run from mariadb or mediawiki folders, this only builds and runs
#  that image. When run from their parent folder (i.e., the project root),
#  this program builds and runs both images, aka DockerWiki.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ENV_FILE="${SCRIPT_DIR}/../.env" # https://stackoverflow.com/a/246128
ENV_DATA="${SCRIPT_DIR}/../.envData"

source ${SCRIPT_DIR}/include.sh
source "$ENV_FILE"
source "$USER_CONFIG" 2>/dev/null

# Basename of working directory.
WHERE=$(basename $(pwd -P))

# Command-line options.
CACHE=true
CLEAN=false
DECORATE=true
INTERACTIVE=false
KLEAN=false

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

  local buildOptions="$1"

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
  xCute docker build $buildOptions $(eval echo "'--tag $IMAGE:'"{$TAGS}) .

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

  local buildOptions=''
  $CACHE || buildOptions='--no-cache'

  local options=(
    MARIADB_ROOT_PASSWORD_HASH "$DW_DB_ROOT_PASSWORD_HASH"
    MARIADB_DATABASE "$DW_DB_NAME"
    MARIADB_USER "$DW_DB_USER"
    MARIADB_PASSWORD_HASH "$DW_DB_PASSWORD_HASH"
  )
  for ((i = 0; $i < ${#options[*]}; i += 2)); do
    buildOptions+=" --build-arg ${options[$i]}=${options[$i + 1]}"
  done

  CONTAINER=$(getContainer data)
  HOST=$DW_DATA_HOST
  IMAGE=$DW_DID/mariadb
  MOUNT="--mount type=volume,src=$DATA_VOLUME,dst=$DATA_TARGET"
  PUBLISH=

  make "$buildOptions"

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mediawiki image.
#
makeView() {

  local buildOptions=''
  $CACHE || buildOptions='--no-cache'

  local options=(
    MW_ADMINISTRATOR "$DW_MW_ADMINISTRATOR"
    MW_PASSWORD "$DW_MW_PASSWORD"
    MW_DB_DATABASE "$DW_DB_NAME"
    MW_DB_USER "$DW_DB_USER"
    MW_DB_PASSWORD "$DW_DB_PASSWORD"
  )
  for ((i = 0; $i < ${#options[*]}; i += 2)); do
    buildOptions+=" --build-arg ${options[$i]}=${options[$i + 1]}"
  done

  CONTAINER=$(getContainer view)
  ENVIRONMENT=
  HOST=$DW_VIEW_HOST
  IMAGE=$DW_DID/mediawiki
  MOUNT=
  PUBLISH="--publish $DW_MW_PORTS"

  make "$buildOptions"

  # No need to configure mediawiki if tearing everything down.
  ($CLEAN || $KLEAN) && return 0

  # Database needs to be Running and Connectable to continue.
  waitForData
  if [ $? -ne 0 ]; then
    echo
    echo "Data container '$(getContainer data)' is unavailable."
    echo "Unable to generate LocalSettings.php."
    echo "Browser may display web-based installer."
    return 1
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
#  Lorem ipsum.
#
parseCommandLine() {
  for arg; do
    case "$arg" in
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
      CACHE=false
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
#  Emulate docker compose name decoration: 'view' => 'wiki-view-1'?
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
#  Summarize usage on request or when command line does not compute.
#
usage() {
  if [ -n "$*" ]; then
    echo && echo "***  $*"
  fi
  cat <<-EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Build and run parts or all of this project.

Options:
  -c | --clean           Remove project's containers and images
  -i | --interactive     Run interactively (1)
  -h | --help            Print this usage summary
  -k | --klean           --clean plus remove volumes and networks!
       --no-cache        Do not use cache when building images
       --no-decoration   Disable composer-naming emulation

Notes:
  1. "run -it" is out of order; STDOUT goes to Tahiti.
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
  local inspect='docker inspect --format' goville='{{json .State.Status}}'

  # Start the database.
  xCute docker start $dataContainer

  # Display issue (status says "running" but cannot talk) as we build...

  cat <<'EOT'

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Note that while 'docker inspect' may show mariadb "running", it
#  may not be "connectable" when it is initializing a new database.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
EOT

  xShow $inspect \"$goville\" $dataContainer
  dataState=$(echo $($inspect "$goville" $dataContainer 2>&1))
  [ "${dataState:0:1}" == \" ] || dataState=\"$dataState\"
  viewState=$(echo $($inspect "$goville" $viewContainer 2>&1))
  [ "${viewState:0:1}" == \" ] || viewState=\"$viewState\"
  echo "Container status: data is $dataState, view is $viewState"

  # Punt. This works albeit painfully as a semaphore.
  local dx="docker exec $dataContainer mariadb -uroot -pchangeThis -e"
  local ac="show databases"
  for ((i = 0; i < 5; ++i)); do
    xShow $dx "'$ac'" && $dx "$ac"
    [ $? == 0 ] && break
    # local status=$?
    # echo Status of that is \$? = $status.
    sleep 1
  done

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

  local running='"running"'

  for ((i = 0; i < 5; ++i)); do

    dataState=$(echo $($inspect "$goville" $dataContainer 2>&1))
    [ "${dataState:0:1}" == \" ] || dataState=\"$dataState\"

    viewState=$(echo $($inspect "$goville" $viewContainer 2>&1))
    [ "${viewState:0:1}" == \" ] || viewState=\"$viewState\"

    echo "Container status: data is $dataState, view is $viewState"

    [ "$dataState" == $running ] && return 0 || sleep 1

  done
  # [ "$dataState" == '"running"' ] && return 0 || sleep 1
  return 1 # nonzero $? indicates failure
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Derrida suggested that philosophy is another form of literature.
#  Software can feel like that sometimes, a kind of mathematical poetry.
#  </EndWax>
#  <BeginLLM>...
#
main "$@"

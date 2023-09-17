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
#  TODO: Hide all the passwords echoed to logs (use secrets).
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source ${SCRIPT_DIR}/include.sh

# Basename of working directory.
WHERE=$(basename $(pwd -P))

# Initialize options.
CACHE=true
oClean=0
INTERACTIVE=false
TIMEOUT=10

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
#  Function returns the .State.Status of a given container. Returned
#  status values have the form '"running"' where the double quotes are
#  part of the string. Errors can be multiline so are collapsed into one
#  line and quoted for simpler presentation.
#
#  From 'docker ps' dockumentation circa 2023, container status can be one
#  of created, restarting, running, removing, paused, exited, or dead.
#  See https://docs.docker.com/engine/reference/commandline/ps/.
#
#  Also see https://docs.docker.com/config/formatting/.
#
getState() {

  local inspect='docker inspect --format' goville='{{json .State.Status}}'

  local container="$1" result="$2" more="$3" options
  while [ -n "$container" -a -n "$result" ]; do
    shift 2
    [ -n "$more" ] && options="-en" || options="-e"
    xShow $options $inspect \"$goville\" $container

    local state=$(echo $($inspect "$goville" $container 2>&1))
    [ "${state:0:1}" = \" ] || state=\"$state\"
    eval $result=$state

    container="$1" result="$2" more="$3"
  done

  if [ -n "$1" ]; then # this would be internal nonsense
    abend "Error: getState() requires an even number of arguments"
  fi
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Yet another entry point.
#
main() {

  isDockerRunning ||
    abend "This program uses docker which appears to be down; aborting."

  parseCommandLine "$@"
  # echo "oClean = '$oClean'"
  # echo "Bye ${LINENO}" && exit ${LINENO}

  # Finish initializing parameters.
  DATA_VOLUME=$(decorate "$DW_DATA_VOLUME" "$DW_PROJECT" 'volume')
  DATA_TARGET=/var/lib/mysql
  NETWORK=$(decorate "$DW_NETWORK" "$DW_PROJECT" 'network')

  # Make one or both services.
  case $WHERE in
  mariadb) makeData ;;
  mediawiki) makeView ;;
  *)
    if [ -f compose.yaml -a -d mariadb -a -d mediawiki ]; then
      if [ $oClean -ge 1 ]; then
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
  if [ $oClean -ge 2 ]; then
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
  [ $oClean -ge 1 ] && return 0

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

  CONTAINER=$(getContainer $DW_DATA_SERVICE)
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
    MW_SITE_NAME "$DW_SITE_NAME"
    # MW_ADMINISTRATOR "$DW_MW_ADMINISTRATOR"
    MW_PASSWORD "$DW_MW_PASSWORD"
    # MW_DB_NAME "$DW_DB_NAME"
    # MW_DB_USER "$DW_DB_USER"
    MW_DB_PASSWORD "$DW_DB_PASSWORD"
  )
  for ((i = 0; $i < ${#options[*]}; i += 2)); do
    buildOptions+=" --build-arg ${options[$i]}=${options[$i + 1]}"
  done

  CONTAINER=$(getContainer $DW_VIEW_SERVICE)
  ENVIRONMENT=
  HOST=$DW_VIEW_HOST
  IMAGE=$DW_DID/mediawiki
  MOUNT=
  PUBLISH="--publish $DW_MW_PORTS"

  make "$buildOptions"

  # No need to configure mediawiki if tearing everything down.
  [ $oClean -ge 1 ] && return 0

  # Database needs to be Running and Connectable to continue.
  waitForData
  if [ $? -ne 0 ]; then
    local error="Error: Cannot connect to data container '$(getContainer $DW_DATA_SERVICE)'; "
    error+="unable to generate LocalSettings.php; "
    error+="browser may display web-based installer."
    echo -e "\n$error"
    return -42
  fi

  # Install / configure mediawiki now that we have a mariadb network.
  # This creates MW DB tables and generates LocalSettings.php file.
  xCute docker exec $CONTAINER maintenance/run CommandLineInstaller \
    --dbtype=mysql --dbserver=data --dbname=mediawiki --dbuser=wikiDBA \
    --dbpassfile="$DW_SITE_NAME/dbpassfile" --passfile="$DW_SITE_NAME/passfile" \
    --scriptpath='' --server='http://localhost:8080' $DW_SITE_NAME $DW_MW_ADMINISTRATOR
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Lorem ipsum.
#
parseCommandLine() {
  set -- $(getOpt "$@")
  while [[ $# -gt 0 ]]; do # https://stackoverflow.com/a/14203146
    case "$1" in
    -c | --clean)
      let oClean++
      shift
      ;;
    -h | --help)
      usage
      ;;
    -i | --interactive)
      INTERACTIVE=true
      shift
      ;;
    --no-cache)
      CACHE=false
      shift
      ;;
    --no-decoration)
      DECORATE=false
      shift
      ;;
    -t | --timeout)
      TIMEOUT="$2"
      shift 2
      if ! [[ $TIMEOUT =~ ^[+]?[1-9][0-9]*$ ]]; then
        usage "--timeout 'seconds': expected a positive integer, found '$TIMEOUT'"
      fi
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

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Summarize usage on request or when command line does not compute.
#
usage() {
  if [ -n "$*" ]; then
    echo && echo "***  $*  ***"
  fi
  cat <<-EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Build and run DockerWiki.

Options:
  -c | --clean             Remove project's containers and images
  -i | --interactive       Run interactively (1)
  -h | --help              Print this usage summary
       --no-cache          Do not use cache when building images
       --no-decoration     Disable composer-naming emulation
  -t | --timeout seconds   Seconds to retry DB connection before failing

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
#  See https://docs.docker.com/engine/reference/commandline/ps/.
#
waitForData() {

  local dataContainer=$(getContainer $DW_DATA_SERVICE) dataState
  local viewContainer=$(getContainer $DW_VIEW_SERVICE) viewState

  # Start the database.
  xCute docker start $dataContainer

  # Display issue as we build (status says "running" but cannot talk)...

  cat <<'EOT'

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Note that while 'docker inspect' may show mariadb "running",
#  it may not be "connectable" when initializing a new database.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
EOT

  getState $dataContainer dataState $viewContainer viewState
  echo -e "\n=> Container status: data is \"$dataState\", view is \"$viewState\"".

  # Punt. This semaphore works albeit painfully.
  local dx="docker exec $dataContainer mariadb -uroot -pchangeThis -e"
  local ac="show databases"

  for ((i = 0; i < $TIMEOUT; ++i)); do
    xShow $dx "'$ac'" && $dx "$ac"
    [ $? -eq 0 ] && break
    sleep 1
  done

  getState $dataContainer dataState $viewContainer viewState
  echo -e "\n=> Container status: data is \"$dataState\", view is \"$viewState\"".

  [ "$dataState" = "running" ] && return 0 || return 1
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Derrida suggested that philosophy is another form of literature.
#  Software can feel like that sometimes, a kind of mathematical poetry.
#  </EndWax>
#  <BeginLLM>...
#
main "$@"

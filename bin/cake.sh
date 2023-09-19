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

set -uo pipefail # pipe status is last-to-fail or zero if none fail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source ${SCRIPT_DIR}/include.sh

# Basename of working directory.
WHERE=$(basename $(pwd -P))

# Initialize options.
oCache=true
oClean=0
oInstaller=cli
oTimeout=10

# Container / runtime configuration.
CONTAINER=
ENVIRONMENT=
HOST=
IMAGE=
MOUNT=
PUBLISH=

# More file scoped stuff (naming please?).
dockerFile=
lastLineCount=0 # see lsTo()
DATA_VOLUME=$(decorate "$DW_DATA_VOLUME" "$DW_PROJECT" 'volume')
DATA_TARGET=/var/lib/mysql
NETWORK=$(decorate "$DW_NETWORK" "$DW_PROJECT" 'network')
DW_SOURCE= # move to .env?

# Contents of a backup directory (see backrest.sh).
readonly gzDatabase=all-databases.sql.gz
readonly imageDir=images
readonly localSettings=LocalSettings.php

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

  (($# >= 2 && $# % 2 == 0)) ||
    die "Error: getState() requires an even number of arguments"

  local inspect='docker inspect --format' goville='{{json .State.Status}}'

  for ((i = 1; i < $#; i += 2)); do
    local j=$((i + 1))
    local container="${!i}" __result="${!j}" options
    ((i + 2 < $#)) && options="-en" || options="-e"
    xShow $options $inspect \"$goville\" $container
    local state=$(echo $($inspect "$goville" $container 2>&1))
    [ "${state:0:1}" = \" ] || state=\"$state\"
    eval $__result=$state
  done

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Common processing for "docker ls" commands using default 'table' format.
#  One could also use JSON format and parse that but here we are.
#
#    Synopsis: lsTo output-variable-name docker some-ls-command ...
#
lsTo() {
  local __outVarName="$1"
  shift
  xShow "$@"
  local __ls=$(xQute2 "$@") || die "docker listing failed: $(getLastError)"
  echo "$__ls" # silence requires another approach; one default here
  lastLineCount=$(echo $(echo "$__ls" | wc -l))
  eval $__outVarName="'$__ls'" # and if $__ls has apostrophe's ??'?
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Yet another entry point.
#
# test() {
#   echo
#   echo "test: CWD = $(pwd -P)"
#   xCute pushd mariadb
#   echo "test: CWD = $(pwd -P)"
#   xCute pushd ../mediawiki
#   echo "test: CWD = $(pwd -P)"
#   popd
#   echo "test: CWD = $(pwd -P)"
#   popd
#   echo "test: CWD = $(pwd -P)"
# }
main() {

  # test
  # echo BYE $LINENO && exit $LINENO

  isDockerRunning || die "Is docker offline? She's not responding."

  parseCommandLine "$@"

  case "$oInstaller" in
  cli) # the default, this runs php in container cli
    dockerFile=Docker/initialize
    ;;
  debug) # includes extra developer tools
    dockerFile=Docker/debug
    ;;
  restore) # restore=path to a DockerWiki backup directory
    local checks=( # It will help reader to spell these out if one is missing...
      -d "$DW_SOURCE"
      -f "$DW_SOURCE/$gzDatabase"
      -f "$DW_SOURCE/$localSettings"
      -d "$DW_SOURCE/$imageDir"
    )
    for ((i = 0; $i < ${#checks[*]}; i += 2)); do
      local op=${checks[$i]} path=${checks[$i + 1]}
      if ! [ $op $path ]; then
        local what
        [ $op == '-d' ] && what=directory || what=file
        echo -e "\nError: $what '$path' not found"
        usage "DockerWiki backup not found for --installer 'restore=$DW_SOURCE'"
      fi
    done
    dockerFile=Docker/restore
    ;;
  web) # leaves bare system for web installer
    dockerFile=Docker/initialize
    ;;
  *) # boo-boos and butt-dials
    usage "Unrecognized --installer '$oInstaller', please check usage"
    ;;
  esac

  # echo "oInstaller = '$oInstaller', DW_SOURCE = '$DW_SOURCE'"
  # echo BYE $LINENO && exit $LINENO

  # Make one or both services.
  case $WHERE in
  mariadb) makeData ;;
  mediawiki) makeView ;;
  *)
    if [ -f compose.yaml -a -d mariadb -a -d mediawiki ]; then
      if [ $oClean -gt 0 ]; then
        xCute pushd mediawiki && makeView && xCute popd
        xCute pushd mariadb && makeData && xCute popd
      else
        xCute pushd mariadb && makeData && xCute popd
        xCute pushd mediawiki && makeView && xCute popd
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
make() { # context is mariadb or mediawiki folder

  local buildOptions=${1:-''}
  local command out tags

  # Remove any existing CONTAINER.
  lsTo out docker container ls --all --filter name=$CONTAINER
  if [ $lastLineCount -gt 1 ]; then
    xCute2 docker stop $CONTAINER && xCute2 docker rm $CONTAINER ||
      die "Error removing container '$CONTAINER': $(getLastError)"
  fi

  # Remove any existing IMAGE(s).
  lsTo out docker image ls $IMAGE
  tags=$(join ',' $(echo "$out" | cut -w -f 2 | grep -v TAG))
  if [ -n "$tags" ]; then
    xCute2 docker rmi $(eval echo "$IMAGE:"{$tags}) ||
      die "Error removing images: $(getLastError)"
  fi

  # Clean up build directories.
  [ $oClean -gt 0 -a -d build ] && xCute rm -fr build 2>/dev/null

  # Remove volumes and networks if requested. First time ignore "still in
  # use" errors; they should leave when second container is processed.
  if [ $oClean -gt 1 ]; then

    lsTo out docker volume ls --filter name=$DATA_VOLUME
    [ $lastLineCount -gt 1 ] && xCute docker volume rm $DATA_VOLUME

    lsTo out docker network ls --filter name=$NETWORK
    [ $lastLineCount -gt 1 ] && xCute docker network rm $NETWORK

  fi

  # Stop here if user only wants to clean up.
  [ $oClean -gt 0 ] && return 0

  # Create a docker volume for the database and a network for chit chat.
  lsTo out docker volume ls --filter name=$DATA_VOLUME
  if [ $lastLineCount -eq 1 ]; then
    xCute2 docker volume create $DATA_VOLUME ||
      die "Error creating volume: $(getLastError)"
  fi
  lsTo out docker network ls --filter name=$NETWORK
  if [ $lastLineCount -eq 1 ]; then
    xCute2 docker network create $NETWORK ||
      die "Error creating network: $(getLastError)"
  fi

  # Build the image.
  command="docker build $buildOptions $(eval echo "'--tag $IMAGE:'"{$TAGS}) ."
  xCute2 $command || die "Build failed: $(getLastError)"

  # Launch container with new image.
  if false; then # --interactive not used / needed, maybe delete?
    command=$(echo docker run $ENVIRONMENT --interactive --rm --tty \
      --network $NETWORK --name $CONTAINER --hostname $HOST \
      --network-alias $HOST $MOUNT $PUBLISH $IMAGE)
  else
    command=$(echo docker run --detach $ENVIRONMENT --network $NETWORK \
      --name $CONTAINER --hostname $HOST --network-alias $HOST $MOUNT \
      $PUBLISH $IMAGE)
  fi
  xCute2 $command || die "Launch failed: $(getLastError)"

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mariadb image.
#
makeData() {

  local buildOptions=''
  $oCache || buildOptions='--no-cache'

  local options=(
    # DW_SOURCE "$DW_SOURCE"
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

  if (($oClean > 0)); then
    make
  else
    # Prepare build directory. We presently sit in mariadb folder.
    [ ! -d build ] || xCute2 rm -fr build || die "rm failed: $(getLastError)"
    xCute2 mkdir build || die "mkdir mariadb/build failed: $(getLastError)"
    xCute2 cp "$dockerFile" build/Dockerfile || die "Copy failed: $(getLastError)"
    xCute2 cp "50-noop.sh" build/ || die "Copy failed: $(getLastError)"
    if [ $oInstaller == 'restore' ]; then
      xCute2 cp "$DW_SOURCE/$gzDatabase" "build/70-initdb.sql.gz" ||
        die "Error copying file: $(getLastError)"
    fi
    # Move context into build subdirectory and fire up docker engine.
    xCute pushd build && make "$buildOptions" && xCute popd
  fi

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mediawiki image.
#
makeView() {

  local buildOptions=''
  $oCache || buildOptions='--no-cache'

  local options=(
    # DW_SOURCE "$DW_SOURCE"
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
  [ $oClean -gt 0 ] && return 0

  # Are we done yet?
  case $oInstaller in
  cli | debug) # use the CLI installer below
    :
    ;;
  web) # base images done, user will find browser wizard
    return 0
    ;;
  *) # backup was restored in Dockerfile (Docker/restore)
    return 0
    ;;
  esac

  # Database needs to be Running and Connectable to continue.
  # if [ $? -ne 0 ]; then
  if ! waitForData; then
    local error="Error: Cannot connect to data container '$(getContainer $DW_DATA_SERVICE)'; "
    error+="unable to generate $localSettings; "
    error+="browser may display web-based installer."
    echo -e "\n$error"
    return -42
  fi

  # Install / configure mediawiki now that we have a mariadb network.
  # This creates MW DB tables and generates LocalSettings.php file.
  command=$(echo docker exec $CONTAINER maintenance/run CommandLineInstaller \
    --dbtype=mysql --dbserver=data --dbname=mediawiki --dbuser=wikiDBA \
    --dbpassfile="$DW_SITE_NAME/dbpassfile" --passfile="$DW_SITE_NAME/passfile" \
    --scriptpath='' --server='http://localhost:8080' $DW_SITE_NAME $DW_MW_ADMINISTRATOR)
  xCute2 $command || die "Error installing mediawiki: $(getLastError)"

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
    -i | --installer) # bash ${p%%/} won't trim more than one '/' so,
      oInstaller=$(perl -pwe 's|/+$||' <<<${2:-''})
      shift 2
      if [ "${oInstaller:0:8}" = "restore=" -a ${#oInstaller} -gt 8 ]; then
        DW_SOURCE=${oInstaller:8}
        oInstaller=restore
      fi
      ;;
    --no-cache)
      oCache=false
      shift
      ;;
    --no-decoration)
      DECORATE=false
      shift
      ;;
    -t | --timeout)
      oTimeout="$2"
      shift 2
      if ! [[ $oTimeout =~ ^[+]?[1-9][0-9]*$ ]]; then
        usage "--timeout 'seconds': expected a positive integer, found '$oTimeout'"
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
    echo -e "\n***  $*  ***" >&2
  fi
  cat >&2 <<EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Build and run DockerWiki.

Options:
  -c | --clean              Remove built artifacts
  -i | --installer string   cli (default), debug, web, or restore=pathToBackup
  -h | --help               Print this usage summary
       --no-cache           Do not use cache when building images
       --no-decoration      Disable composer-naming emulation
  -t | --timeout seconds    Seconds to retry DB connection before failing
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
  xCute2 docker start $dataContainer ||
    die "Cannot start '$dataContainer': $(getLastError)"

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

  for ((i = 0; i < $oTimeout; ++i)); do
    xShow $dx "'$ac'" && $dx "$ac" && break
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

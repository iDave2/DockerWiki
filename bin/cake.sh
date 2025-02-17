#!/usr/bin/env bash
#
#  Something to build and run things:
#
#    $ ./cake.sh        # create everything
#    $ ./cake.sh -cccc  # destroy everything
#    $ ./cake.sh -h     # print usage summary
#
#  When run from mariadb or mediawiki folders, this only builds and runs
#  that image. When run from their parent folder (i.e., the project root),
#  this program builds and runs both images, aka DockerWiki.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ScriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${ScriptDir}/bootstrap.sh"

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
dockerFile=Dockerfile
dataVolume=$(decorate "$DW_DATA_VOLUME" "$DW_PROJECT" 'volume')
dataTarget=/var/lib/mysql
network=$(decorate "$DW_NETWORK" "$DW_PROJECT" 'network')
BACKUP_DIR= # --installer restore=BACKUP_DIR

# Contents of a backup directory (see backrest.sh).
readonly gzDatabase=$DW_DB_NAME.sql.gz
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
#  Yet another entry point.
#
main() {

  isDockerRunning || die "Please check docker, I cannot connect."

  parseCommandLine "$@"

  # Make one or both services.
  case $WHERE in
  mariadb) makeData ;;
  mediawiki) makeView ;;
  *)
    if [ -f compose.yaml -a -d mariadb -a -d mediawiki ]; then
      if test $oClean -gt 0; then
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
#  Create or destroy an image and its container. Current context is
#  mariadb/build or mediawiki/build.
#
make() {

  local buildOptions=${1:-''}
  local command out
  # this local game may be hopeless - bash reports undefined usage, not unused vars

  makeClean

  # Stop here if user only wants to clean up.
  (($oClean > 0)) && return 0

  # Create a docker volume for the database and a network for chit chat.
  xCute12 docker volume ls --filter name=$dataVolume ||
    die "Error listing data volume: $(getLastError)"
  echo "$(getLastOutput)" && mapfile -t < <(getLastOutput)
  if ((${#MAPFILE[@]} == 1)); then
    xCute2 docker volume create $dataVolume ||
      die "Error creating volume: $(getLastError)"
  fi
  xCute12 docker network ls --filter name=$network ||
    die "Error listing data volume: $(getLastError)"
  echo "$(getLastOutput)" && mapfile < <(getLastOutput)
  if ((${#MAPFILE[@]} == 1)); then
    xCute2 docker network create $network ||
      die "Error creating network: $(getLastError)"
  fi

  # Build the image.
  command="docker build $buildOptions --tag $IMAGE:$DW_TAG ."
  xCute2 $command || die "Build failed: $(getLastError)"
  for ((i = 0; i < ${#DW_EXTRA_TAGS[*]}; i++)); do
    xCute2 docker image tag $IMAGE:$DW_TAG $IMAGE:${DW_EXTRA_TAGS[$i]} ||
      die "Error tagging '$IMAGE:$DW_TAG <- $IMAGE:${DW_EXTRA_TAGS[$i]}'"
  done

  # Launch a container with new image.
  xCute2 docker run --detach $ENVIRONMENT --network $network \
    --name $CONTAINER --hostname $HOST --network-alias $HOST \
    $MOUNT $PUBLISH $IMAGE:$DW_TAG ||
    die "Launch failed: $(getLastError)"

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Called from make() to clean up either by request or to rebuild
#  something.
#
makeClean() {

  local command out

  # Build directories are created during builds before this cleaning
  # step. So do not erase build directories when building!
  # Erase build directories on request (-c).
  if (($oClean > 0)); then
    [ -d build ] && xCute rm -fr build
  fi

  # Remove existing CONTAINERs sometimes (-cc).
  if (($oClean == 0 || $oClean > 1)); then
    xCute12 docker container ls --all --filter name=$CONTAINER ||
      die "Error listing containers: $(getLastError)"
    echo "$(getLastOutput)" && mapfile -t < <(getLastOutput)
    if [ ${#MAPFILE[@]} -gt 1 ]; then
      xCute2 docker rm --force $CONTAINER ||
        die "Error removing container '$CONTAINER': $(getLastError)"
    fi
  fi

  # No need to remove NETWORKs during builds but they are removed
  # by request (-cc). This means "cake -cc" removes just enough
  # to test docker compose on the images remaining in Docker Desktop.
  if (($oClean > 1)); then
    xCute12 docker network ls --filter name=$network ||
      die "Error listing networks: $(getLastError)"
    echo "$(getLastOutput)" && mapfile -t < <(getLastOutput)
    test ${#MAPFILE[@]} -gt 1 && xCute docker network rm $network
  fi

  # Remove existing IMAGEs sometimes (-ccc).
  if (($oClean == 0 || $oClean > 2)); then
    xCute12 docker image ls $IMAGE ||
      die "Error listing images: $(getLastError)"
    echo "$(getLastOutput)" && mapfile < <(getLastOutput)
    local tags=($(echo "${MAPFILE[@]:1}" | sed -e 's/^ *//' | cut -w -f 2))
    # echo tags = "${tags[@]}"
    if ((${#tags[*]} > 0)); then # https://stackoverflow.com/a/13216833
      local images=(${tags[@]/#/${IMAGE}:})
      xCute2 docker rmi "${images[@]}" ||
        die "Error removing images: $(getLastError)"
    fi
  fi

  # Remove volumes if requested (-cccc). "Still in use"
  # errors can be ignored on first container; they leave when
  # second container is removed, no longer using the resource.
  if (($oClean > 3)); then
    xCute12 docker volume ls --filter name=$dataVolume ||
      die "Error listing volumes: $(getLastError)"
    echo "$(getLastOutput)" && mapfile < <(getLastOutput)
    ((${#MAPFILE[@]} > 1)) && xCute docker volume rm $dataVolume
  fi

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mariadb image.
#
makeData() {

  CONTAINER=$(getContainer $DW_DATA_SERVICE)
  HOST=$DW_DATA_HOST
  IMAGE=$DW_HID/mariadb
  MOUNT="--mount type=volume,src=$dataVolume,dst=$dataTarget"
  PUBLISH=

  if (($oClean > 0)); then
    make # just cleanup, no build & run
    return
  fi

  # Prepare build directory. We presently sit in mariadb folder.
  [ ! -d build ] || xCute2 rm -fr build || die "rm failed: $(getLastError)"
  xCute2 mkdir build || die "mkdir mariadb/build failed: $(getLastError)"
  xCute2 cp "$dockerFile" build/Dockerfile &&
    cp 20-noop.sh build/20-noop.sh &&
    cp root-password-file build/mariadb-root-password-file &&
    cp show-databases build/mariadb-show-databases ||
    die "Copy failed: $(getLastError)"

  # Prepare build command line and gather inputs.
  local buildOptions=''
  $oCache || buildOptions='--no-cache'

  if test $oInstaller == 'restore'; then
    xCute2 cp "$BACKUP_DIR/$gzDatabase" build/ || die "Copy failed: $(getLastError)"
    buildOptions+=" --build-arg VERSION=restore"
    buildOptions+=" --build-arg DW_DB_NAME=$DW_DB_NAME"
  else
    xCute2 cp password-file build/mariadb-password-file ||
      die "Copy failed: $(getLastError)"
    buildOptions+=" --build-arg MARIADB_ROOT_HOST=$DW_DB_ROOT_HOST"
    buildOptions+=" --build-arg MARIADB_DATABASE=$DW_DB_NAME"
    buildOptions+=" --build-arg MARIADB_USER=$DW_DB_USER"
  fi

  # Move context into build subdirectory and wake up docker engine.
  xCute pushd build && make "$buildOptions" && xCute popd

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mediawiki image.
#
makeView() {

  CONTAINER=$(getContainer $DW_VIEW_SERVICE)
  ENVIRONMENT=
  HOST=$DW_VIEW_HOST
  IMAGE=$DW_HID/mediawiki
  MOUNT=
  PUBLISH="--publish $DW_MW_PORTS"
  TONY=/root # Maria's boyfriend.

  if (($oClean > 0)); then
    make # just cleanup, no build & run
    return
  fi

  # Prepare build directory. We presently sit in mediawiki folder.
  test ! -d build || xCute2 rm -fr build || die "rm failed: $(getLastError)"
  xCute2 mkdir build || die "mkdir mediawiki/build failed: $(getLastError)"
  xCute2 cp "$dockerFile" build/Dockerfile || die "Copy failed: $(getLastError)"

  # Prepare build command line and gather inputs.
  local buildOptions=''
  $oCache || buildOptions='--no-cache'
  buildOptions+=" --build-arg TONY=$TONY"
  if test $oInstaller == 'restore'; then
    xCute2 cp -R "$BACKUP_DIR/$localSettings" "$BACKUP_DIR/$imageDir" build/ ||
      die "Error copying file: $(getLastError)"
    buildOptions+=" --build-arg VERSION=restore"
  else
    xCute2 cp admin-password-file build/passfile &&
      cp password-file build/dbpassfile ||
      die "Copy failed: $(getLastError)"
  fi

  # Move context into build subdirectory and wake up docker engine.
  xCute pushd build && make "$buildOptions" && xCute popd

  # Are we done yet?
  case $oInstaller in
  restore | web) return 0 ;; # done, user continues in browser
  esac

  # Database needs to be Running and Connectable to continue.
  if ! waitForData; then
    local error="Error: Cannot connect to data container '$(getContainer $DW_DATA_SERVICE)'; "
    error+="unable to generate $localSettings; "
    error+="browser may display web-based installer."
    echo -e "\n$error"
    return -42
  fi

  # Install / configure mediawiki using famous PHP language.
  # This creates MW DB tables and generates LocalSettings.php file.
  local port=${DW_MW_PORTS%:*} # 127.0.0.1:8080:80 -> 127.0.0.1:8080
  port=${port#*:}              # 127.0.0.1:8080 -> 8080
  command=$(echo docker exec $CONTAINER maintenance/run CommandLineInstaller \
    --dbtype=mysql --dbserver=$DW_DATA_HOST --dbname=$DW_DB_NAME --dbuser=$DW_DB_USER \
    --dbpassfile="$TONY/dbpassfile" --passfile="$TONY/passfile" \
    --scriptpath='' --server="http://localhost:$port" $DW_SITE $DW_MW_ADMIN)
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
    -i | --installer)
      local reset=$(shopt -p extglob)
      shopt -s extglob      # https://stackoverflow.com/a/4555979
      oInstaller=${2%%+(/)} # Remove trailing '/'s
      $reset
      # echo && echo "[internal]" After reset "\$($reset)", found \"$(shopt extglob)\".
      shift 2
      case "$oInstaller" in
      cli | web) # No problema
        ;;
      restore=*)
        BACKUP_DIR=${oInstaller:8}
        test -n "$BACKUP_DIR" &&
          test -d "$BACKUP_DIR" &&
          test -f "$BACKUP_DIR/$gzDatabase" &&
          test -f "$BACKUP_DIR/$localSettings" &&
          test -d "$BACKUP_DIR/$imageDir" ||
          die Cannot restore from "'$BACKUP_DIR'", please check location
        BACKUP_DIR=$(realpath ${BACKUP_DIR}) # TODO: weak death knell above
        oInstaller=restore
        ;;
      *) # boo-boos and butt-dials
        usage "Unrecognized --installer '$oInstaller'; please check usage"
        ;;
      esac
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
  -c | --clean              Remove (up to -cccc) build artifacts
  -i | --installer string   'cli' (default), 'web', or 'restore=<dir>'
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

  local format="\n=> Container status: %s is \"%s\", %s is \"%s\"\n"

  getState $dataContainer dataState $viewContainer viewState
  printf "$format" $dataContainer $dataState $viewContainer $viewState

  # Punt. Here's a semaphore.
  for ((i = 0; i < $oTimeout; ++i)); do
    xCute docker exec $dataContainer /root/mariadb-show-databases && break
    sleep 2
  done

  getState $dataContainer dataState $viewContainer viewState
  printf "$format" $dataContainer $dataState $viewContainer $viewState

  [ "$dataState" = "running" ] && return 0 || return 1

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Derrida suggested that philosophy is another form of literature.
#  Software can feel like that sometimes, a kind of mathematical poetry.
#  </EndWax>
#  <BeginLLM>...
#
cat <<EOT

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  BEGIN ${0##*/} at $(date +%H:%M) with args ($(join ', ' "$@")).
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
EOT

main "$@"

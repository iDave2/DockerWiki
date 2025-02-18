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

WorkingDir=$(basename $(pwd -P)) # Current working directory
BannerShown=false                # Flag to print banner just once
LaunchArgs=("$@")                # Memory bank for showBannner

# Command-line options.
OpCache=true    # Use build cache?
OpClean=0       # Clean (remove) artifacts?
OpInstaller=cli # Type of mediawiki installer to use
OpTimeout=10    # Periods to wait for database to wake up

# Container / runtime configurations.
Container=
Environment=
Host=
Image=
Mount=
Publish=

# Miscellaneous.
BackupDir= # --installer restore=BackupDir
DockerFile=Dockerfile
DataVolume=$(decorate "$DW_DATA_VOLUME" "$DW_PROJECT" 'volume')
DataTarget=/var/lib/mysql
Network=$(decorate "$DW_NETWORK" "$DW_PROJECT" 'network')

# Contents of a BackUp directory (see backrest.sh).
readonly BuDatabase=$DW_DB_NAME.sql.gz
readonly BuImageDir=images
readonly BuLocalSettings=LocalSettings.php

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

  # LaunchArgs=("$@") # Save for banner.

  parseCommandLine "$@"

  # Make one or both services.
  case $WorkingDir in
  mariadb) makeData ;;
  mediawiki) makeView ;;
  *)
    if [ -f compose.yaml -a -d mariadb -a -d mediawiki ]; then
      if test $OpClean -gt 0; then
        xCute pushd mediawiki && makeView && xCute popd
        xCute pushd mariadb && makeData && xCute popd
      else
        xCute pushd mariadb && makeData && xCute popd
        xCute pushd mediawiki && makeView && xCute popd
      fi
    else
      local projectDir=$(realpath $ScriptDir/..)
      local message=$'This program must be run from \'mariadb\', \'mediawiki\',\n'
      # local line2="    or '$projectDir', not '$WorkingDir'."
      # usage "$line1 $line2"
      message+="    or '$projectDir', not '$WorkingDir'."
      usage "$line1"
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
  (($OpClean > 0)) && return 0

  # Create a docker volume for the database and a network for chit chat.
  xCute12 docker volume ls --filter name=$DataVolume ||
    die "Error listing data volume: $(getLastError)"
  echo "$(getLastOutput)" && mapfile -t < <(getLastOutput)
  if ((${#MAPFILE[@]} == 1)); then
    xCute2 docker volume create $DataVolume ||
      die "Error creating volume: $(getLastError)"
  fi
  xCute12 docker network ls --filter name=$Network ||
    die "Error listing data volume: $(getLastError)"
  echo "$(getLastOutput)" && mapfile < <(getLastOutput)
  if ((${#MAPFILE[@]} == 1)); then
    xCute2 docker network create $Network ||
      die "Error creating network: $(getLastError)"
  fi

  # Build the image.
  command="docker build $buildOptions --tag $Image:$DW_TAG ."
  xCute2 $command || die "Build failed: $(getLastError)"
  for ((i = 0; i < ${#DW_EXTRA_TAGS[*]}; i++)); do
    xCute2 docker image tag $Image:$DW_TAG $Image:${DW_EXTRA_TAGS[$i]} ||
      die "Error tagging '$Image:$DW_TAG <- $Image:${DW_EXTRA_TAGS[$i]}'"
  done

  # Launch a container with new image.
  xCute2 docker run --detach $Environment --network $Network \
    --name $Container --hostname $Host --network-alias $Host \
    $Mount $Publish $Image:$DW_TAG ||
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
  if (($OpClean > 0)); then
    [ -d build ] && xCute rm -fr build
  fi

  # Remove existing CONTAINERs sometimes (-cc).
  if (($OpClean == 0 || $OpClean > 1)); then
    xCute12 docker container ls --all --filter name=$Container ||
      die "Error listing containers: $(getLastError)"
    echo "$(getLastOutput)" && mapfile -t < <(getLastOutput)
    if [ ${#MAPFILE[@]} -gt 1 ]; then
      xCute2 docker rm --force $Container ||
        die "Error removing container '$Container': $(getLastError)"
    fi
  fi

  # No need to remove NETWORKs during builds but they are removed
  # by request (-cc). This means "cake -cc" removes just enough
  # to test docker compose on the images remaining in Docker Desktop.
  if (($OpClean > 1)); then
    xCute12 docker network ls --filter name=$Network ||
      die "Error listing networks: $(getLastError)"
    echo "$(getLastOutput)" && mapfile -t < <(getLastOutput)
    test ${#MAPFILE[@]} -gt 1 && xCute docker network rm $Network
  fi

  # Remove existing IMAGEs sometimes (-ccc).
  if (($OpClean == 0 || $OpClean > 2)); then
    xCute12 docker image ls $Image ||
      die "Error listing images: $(getLastError)"
    echo "$(getLastOutput)" && mapfile < <(getLastOutput)
    local tags=($(echo "${MAPFILE[@]:1}" | sed -e 's/^ *//' | cut -w -f 2))
    # echo tags = "${tags[@]}"
    if ((${#tags[*]} > 0)); then # https://stackoverflow.com/a/13216833
      local images=(${tags[@]/#/${Image}:})
      xCute2 docker rmi "${images[@]}" ||
        die "Error removing images: $(getLastError)"
    fi
  fi

  # Remove volumes if requested (-cccc). "Still in use"
  # errors can be ignored on first container; they leave when
  # second container is removed, no longer using the resource.
  if (($OpClean > 3)); then
    xCute12 docker volume ls --filter name=$DataVolume ||
      die "Error listing volumes: $(getLastError)"
    echo "$(getLastOutput)" && mapfile < <(getLastOutput)
    ((${#MAPFILE[@]} > 1)) && xCute docker volume rm $DataVolume
  fi

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mariadb image.
#
makeData() {

  showBanner

  Container=$(getContainer $DW_DATA_SERVICE)
  Host=$DW_DATA_HOST
  Image=$DW_HID/mariadb
  Mount="--mount type=volume,src=$DataVolume,dst=$DataTarget"
  Publish=

  if (($OpClean > 0)); then
    make # just cleanup, no build & run
    return
  fi

  # Prepare build directory. We presently sit in mariadb folder.
  [ ! -d build ] || xCute2 rm -fr build || die "rm failed: $(getLastError)"
  xCute2 mkdir build || die "mkdir mariadb/build failed: $(getLastError)"

  # Prepare contents of build directory.
  declare -An map=( # Associative arrays? Six or a half dozen?
    $DockerFile Dockerfile
    20-noop.sh 20-noop.sh
    password-file mariadb-password-file
    root-password-file mariadb-root-password-file
    show-databases mariadb-show-databases
  )
  for i in "${!map[@]}"; do # https://stackoverflow.com/a/3113285
    xCute2 cp "$i" "build/${map[$i]}" || die "Copy failed: $(getLastError)"
  done
  # xCute2 cp "$DockerFile" build/Dockerfile &&
  #   cp 20-noop.sh build/20-noop.sh &&
  #   cp password-file build/mariadb-password-file &&
  #   cp root-password-file build/mariadb-root-password-file &&
  #   cp show-databases build/mariadb-show-databases ||
  #   die "Copy failed: $(getLastError)"

  # Prepare build command line and gather inputs.
  local buildOptions=''
  $OpCache || buildOptions='--no-cache'
  buildOptions+=" --build-arg MARIADB_ROOT_HOST=$DW_DB_ROOT_HOST"
  buildOptions+=" --build-arg MARIADB_DATABASE=$DW_DB_NAME"
  buildOptions+=" --build-arg MARIADB_USER=$DW_DB_USER"

  if test $OpInstaller == 'restore'; then
    xCute2 cp "$BackupDir/$BuDatabase" build/ || die "Copy failed: $(getLastError)"
    buildOptions+=" --build-arg VERSION=restore"
  fi

  # Move context into build subdirectory and wake up docker engine.
  xCute pushd build && make "$buildOptions" && xCute popd

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mediawiki image.
#
makeView() {

  showBanner

  # Associative array looks like this (for compare/contrast):
  #
  #   declare -A C=(ConfigDefault) # keys with empty values
  #   ${C[Container]}=$(getContainer $DW_VIEW_SERVICE)
  #   ${C[Host]}=$DW_VIEW_HOST
  #   ${C[Image]}=$DW_HID/mediawiki
  #   ${C[Publish]}="--publish $DW_MW_PORTS"
  #   ${C[TONY]}=/root
  #
  # Not sure the nice encapsulation offsets the more complex notation.
  #
  Container=$(getContainer $DW_VIEW_SERVICE)
  Environment=
  Host=$DW_VIEW_HOST
  Image=$DW_HID/mediawiki
  Mount=
  Publish="--publish $DW_MW_PORTS"
  TONY=/root # Maria's boyfriend.

  if (($OpClean > 0)); then
    make # just cleanup, no build & run
    return
  fi

  # Prepare build directory. We presently sit in mediawiki folder.
  test ! -d build || xCute2 rm -fr build || die "rm failed: $(getLastError)"
  xCute2 mkdir build || die "mkdir mediawiki/build failed: $(getLastError)"
  xCute2 cp "$DockerFile" build/Dockerfile || die "Copy failed: $(getLastError)"

  # Prepare build command line and gather inputs.
  local buildOptions=''
  $OpCache || buildOptions='--no-cache'
  buildOptions+=" --build-arg TONY=$TONY"
  if test $OpInstaller == 'restore'; then
    xCute2 cp -R "$BackupDir/$BuLocalSettings" "$BackupDir/$BuImageDir" build/ ||
      die "Error copying file: $(getLastError)"
    buildOptions+=" --build-arg VERSION=restore"
  else
    xCute2 cp admin-password-file build/passfile &&
      cp password-file build/dbpassfile ||
      die "Copy failed: $(getLastError)"
  fi

  # Move context into build subdirectory and wake up docker engine.
  xCute pushd build && make "$buildOptions" && xCute popd

  # Database needs to be Running and Connectable to continue.
  if ! waitForData; then
    local error="Error: Cannot connect to data container '$(getContainer $DW_DATA_SERVICE)'; "
    error+="unable to generate $BuLocalSettings; "
    error+="browser may display web-based installer."
    echo -e "\n$error"
    return -42
  fi

  # Are we done yet?
  if test $OpInstaller = 'restore'; then
    cat <<'EOT'
#
#  Build complete, system restored.
#
EOT
  elif test $OpInstaller = 'web'; then
    cat <<'EOT'
#
#  Build complete, finish configuration in browser.
#
EOT
  fi
  case $OpInstaller in
  restore | web)
    # Also see https://stackoverflow.com/a/23039509.
    open 'http://localhost:8080/'
    return 0
    ;;
  esac

  # Install / configure mediawiki using famous PHP language.
  # This creates MW DB tables and generates LocalSettings.php file.
  local port=${DW_MW_PORTS%:*} # 127.0.0.1:8080:80 -> 127.0.0.1:8080
  port=${port#*:}              # 127.0.0.1:8080 -> 8080
  command=$(echo docker exec $Container maintenance/run CommandLineInstaller \
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
      let OpClean++
      shift
      ;;
    -h | --help)
      usage
      ;;
    -i | --installer)
      local reset=$(shopt -p extglob)
      shopt -s extglob       # https://stackoverflow.com/a/4555979
      OpInstaller=${2%%+(/)} # Remove trailing '/'s
      $reset
      # echo && echo "[internal]" After reset "\$($reset)", found \"$(shopt extglob)\".
      shift 2
      case "$OpInstaller" in
      cli | web) # No problema
        ;;
      restore=*)
        BackupDir=${OpInstaller:8}
        test -n "$BackupDir" &&
          test -d "$BackupDir" &&
          test -f "$BackupDir/$BuDatabase" &&
          test -f "$BackupDir/$BuLocalSettings" &&
          test -d "$BackupDir/$BuImageDir" ||
          die Cannot restore from "'$BackupDir'", please check location
        BackupDir=$(realpath ${BackupDir}) # TODO: weak death knell above
        OpInstaller=restore
        ;;
      *) # boo-boos and butt-dials
        usage "Unrecognized --installer '$OpInstaller'; please check usage"
        ;;
      esac
      ;;
    --no-cache)
      OpCache=false
      shift
      ;;
    --no-decoration)
      DECORATE=false
      shift
      ;;
    -t | --timeout)
      OpTimeout="$2"
      shift 2
      if ! [[ $OpTimeout =~ ^[+]?[1-9][0-9]*$ ]]; then
        usage "--timeout 'seconds': expected a positive integer, found '$OpTimeout'"
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
#  Make start of long outputs easier to see.
#
showBanner() {
  if $BannerShown; then return; fi
  BannerShown=true
  local args=$(join ', ' "${LaunchArgs[@]}")
  cat <<EOT

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  BEGIN ${0##*/} at $(date +%H:%M) with args ($args).
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
EOT
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Summarize usage on request or when command line does not compute.
#
usage() {
  if [ -n "$*" ]; then
    echo -e "\n***  $@  ***" >&2
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
  for ((i = 0; i < $OpTimeout; ++i)); do
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
main "$@"

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
SiteURL='http://localhost:8080/'

# Contents of a BackUp directory (see backrest.sh).
Database=$DB_DATABASE.sql
readonly ImageDir=images
readonly LSettings=LocalSettings.php

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Yet another entry point.
#
main() {

  isDockerRunning || die "Please check docker, I cannot connect."

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
      local message projectDir=$(realpath $ScriptDir/..)
      read -r -d '' message <<EOT # https://stackoverflow.com/a/1655389
This program must be run from
      ${projectDir}/mariadb or
       ${projectDir}/mediawiki or
        ${projectDir}
         but not $(
        pwd -P
      )
EOT
      usage "$message"
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

  local buildOptions=${1:-''} command

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
  xShow $command # xCute garbles output, if any
  $command || die "Build failed: $(getLastError)"
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
  #
  # 251227: Our $Image here is the .Repository in json schema and the
  # default output format changed since our last visit so let us use
  # the go-language format specs here and elsewhere when available;
  # maybe better persistence, at least until the json schema changes. ;)
  #
  if (($OpClean == 0 || $OpClean > 2)); then
    xCute12 docker image ls --format '{{.Tag}}' $Image ||
      die "Error listing images: $(getLastError)"
    echo "$(getLastOutput)"
    local tags=($(getLastOutput))
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

  # Initialize build options.
  local buildOptions=''
  $OpCache || buildOptions='--no-cache'
  buildOptions+=" --build-arg MARIA=/root" # TODO: hard-coded?
  buildOptions+=" --build-arg VERSION=$OpInstaller"

  # Prepare contents of build directory.
  echo $DB_ROOT_PASSWORD >build/$DB_ROOT_PASSWORD_FILE
  test -f build/$DB_ROOT_PASSWORD_FILE &&
    xCute2 cp "$DockerFile" 20-noop.sh build/ ||
    die "Copy failed: $(getLastError)"
  buildOptions+=" --build-arg DB_ROOT_PASSWORD_FILE=$DB_ROOT_PASSWORD_FILE"

  # Keep preparing. Can't be too prepared.
  case $OpInstaller in
  web) ;;
  restore)
    xCute2 cp "$BackupDir/$Database" build/ || die "Copy failed: $(getLastError)"
    if test "${Database%.gz}" = "${Database}"; then
      xCute2 gzip "build/$Database" || die "Gzip failed: $(getLastError)"
    fi
    ;& # Fall through...
  cli)
    buildOptions+=" --build-arg MARIADB_ROOT_HOST=$DB_ROOT_HOST"
    buildOptions+=" --build-arg MARIADB_DATABASE=$DB_DATABASE"
    buildOptions+=" --build-arg MARIADB_USER=$DB_USER"
    echo $DB_USER_PASSWORD >build/$DB_USER_PASSWORD_FILE
    test -f build/$DB_USER_PASSWORD_FILE &&
      xCute2 cp show-databases build/mariadb-show-databases ||
      die "Copy failed: $(getLastError)"
    buildOptions+=" --build-arg DB_USER_PASSWORD_FILE=$DB_USER_PASSWORD_FILE"
    ;;
  esac

  # Move context into build subdirectory and wake up docker engine.
  xCute pushd build && make "$buildOptions" && xCute popd

}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Configure make() to create or destroy a mediawiki image.
#
makeView() {

  showBanner

  Container=$(getContainer $DW_VIEW_SERVICE)
  Environment=
  Host=$DW_VIEW_HOST
  Image=$DW_HID/mediawiki
  Mount=
  Publish="--publish $MW_PORTS"
  TONY=/root # Maria's boyfriend.

  if (($OpClean > 0)); then
    make # just cleanup, no build & run
    return
  fi

  local buildOptions lastWords isWikiUp timer

  # Prepare build directory. We presently sit in mediawiki folder.
  test ! -d build || xCute2 rm -fr build || die "rm failed: $(getLastError)"
  xCute2 mkdir build || die "mkdir mediawiki/build failed: $(getLastError)"
  xCute2 cp "$DockerFile" build/Dockerfile || die "Copy failed: $(getLastError)"

  # Prepare build command line and gather inputs.
  $OpCache || buildOptions='--no-cache'
  buildOptions+=" --build-arg CACHE_DATE=$(date '+%y%m%d.%H%M%S')"
  buildOptions+=" --build-arg TONY=$TONY"
  buildOptions+=" --build-arg VERSION=$OpInstaller"
  case $OpInstaller in
  web)
    lastWords="Build complete, finish configuration in browser."
    ;;
  cli)
    lastWords="Build completed successfully."
    echo $MW_ADMIN_PASSWORD >build/passfile
    echo $DB_USER_PASSWORD >build/dbpassfile
    test -f build/passfile && test -f build/dbpassfile ||
      die "Copy failed: $(getLastError)"
    ;;
  restore)
    lastWords="Build complete, system restored."
    xCute2 cp -R "$BackupDir/$LSettings" "$BackupDir/$ImageDir" build/ ||
      die "Error copying file: $(getLastError)"
    ;;
  esac

  # Move context into build subdirectory and wake up docker engine.
  xCute pushd build && make "$buildOptions" && xCute popd

  # Are we done yet?
  if $OpInstaller eq 'web'; then
    waitForView 15 || die "Trouble starting view: $(getLastError)"
    cat <<EOT

#
#  $lastWords
#
EOT
    browse $SiteURL # Also see https://stackoverflow.com/a/23039509.
    return 0        # Web installer stops here.
  fi

  # Database needs to be Running and Connectable to continue.
  if ! waitForData; then
    local error="Error: Cannot connect to data container '$(getContainer $DW_DATA_SERVICE)'; "
    error+="unable to generate $LSettings; "
    error+="browser may display web-based installer."
    echo -e "\n$error"
    return -42
  fi

  if test $OpInstaller = 'cli'; then

    # Install / configure mediawiki using the famous PHP language.
    # This creates MW DB tables and generates LocalSettings.php file.
    local port=${MW_PORTS%:*} # 127.0.0.1:8080:80 -> 127.0.0.1:8080
    port=${port#*:}           # 127.0.0.1:8080 -> 8080
    local command=$(echo docker exec $Container \
      maintenance/run install \
      --dbtype=mysql \
      --dbserver=$DW_DATA_HOST \
      --dbname=$DB_DATABASE \
      --dbuser=$DB_USER \
      --dbpassfile="$TONY/dbpassfile" \
      --passfile="$TONY/passfile" \
      --scriptpath='' \
      --server="http://localhost:$port" \
      --with-extensions \
      $MW_SITE $MW_ADMIN)
    xCute2 $command || die "Error installing mediawiki: $(getLastError)"

  else # 'restore'

    xCute2 configure.sh || dieLastError

  fi

  cat <<EOT

#
#  $lastWords
#
EOT
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
        test ! -f "$BackupDir/$Database" &&
          test -f "$BackupDir/$Database.gz" &&
          Database+=".gz"
        test -n "$BackupDir" &&
          test -d "$BackupDir" &&
          test -f "$BackupDir/$Database" &&
          test -f "$BackupDir/$LSettings" &&
          test -d "$BackupDir/$ImageDir" ||
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
EOT
  exit 1
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Derrida suggested that philosophy is another form of literature.
#  Software can feel like that sometimes, a kind of mathematical poetry.
#  </EndWax>
#  <BeginLLM>...
#
main "$@"

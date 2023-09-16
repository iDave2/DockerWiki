#!/usr/bin/env bash
#
#  Backup and restore tools adapted from hub pages for official
#  mediawiki and mariadb images.
#
#  This script passes cleartext passwords so is Not Secure.
#  This script requires 'bash' and 'jq'.
#
#  Let's try camel case for file scope hint, uppercase for globals.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

set -uo pipefail # pipe status is last-to-fail or zero if none fail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/include.sh" # https://stackoverflow.com/a/246128

# What to do.
BACKUP=false
force=false
QUIET=true
RESTORE=false

# Where to do it.
hostRoot=                # see --from-to
wikiRoot="/var/www/html" # docroot inside view container
dataFile=all-databases.sql
imageDir=images
localSettings=LocalSettings.php

# Defaults subject to change via command line options.
dataContainer=$(getContainer data)
viewContainer=$(getContainer view)

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Validate requested data and view containers.
#
checkContainer() {

  local container=$1 hostName=$2 imageName=$3

  local inspect="docker container inspect $container"
  local jayQ="jq --raw-output"
  local filter=".[0].Config.Hostname, .[0].Config.Image"

  xShow $inspect '|' $jayQ "'$filter'"

  xQute12 $inspect
  [ $? -ne 0 ] && abend "Error: failed to inspect '$container': $(getLastError)"

  local hostImage=$(echo $(getLastOutput | $jayQ "$filter"))
  local hostTest=$(echo $hostImage | cut -w -f 1)
  local imageTest=$(echo $hostImage | cut -w -f 2)
  echo "$hostTest $imageTest"
  imageTest=$(echo $(basename $imageTest) | sed -e s/:.*//)
  # idave2/mariadb:0.2.0 => mariadb

  if [ "$hostTest" != "$hostName" ]; then
    usage "Expected host '$hostName' for container '$container'; found '$hostTest' instead"
  fi
  if [ "$imageTest" != "$imageName" ]; then
    usage "Expected image '$imageName' for container '$container'; found '$imageTest' instead"
  fi
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  chatgpt://get/quote?keyword="main"&limit=1
#
main() {

  isDockerRunning || abend "Is docker down? I cannot connect."

  parseCommandLine "$@"

  # Precendence unclear And it seems to work...
  ($BACKUP && $RESTORE) || (! $BACKUP && ! $RESTORE) &&
    usage "Please specify either --backup or --restore"

  if $BACKUP; then
    [ -n "$hostRoot" ] || hostRoot="$(getTempDir)/backup-$(date '+%y%m%d-%H%M%S')"
    for dir in "$hostRoot" "$hostRoot/$imageDir"; do
      echo "dir is '$dir'"
    done
    # "br -b -w DockerWiki/foo --force" hangs when --force was added!
    for dir in "$hostRoot" "$hostRoot/$imageDir"; do
      :
      # if [ -d "$dir" ]; then
      #   echo HELLO 89 && exit 89
      #   # if [ ! $force ]; then
      #   #   usage "Use --force to reuse working dir '$dir'"
      #   # fi
      #   echo HELLO 87 && exit 87
      # else
      #   xKute2 mkdir "$dir"
      #   [ $? -ne 0 ] && usage "Trouble creating '$dir': $(getLastError)"
      # fi
    done
    echo BYE ${LINENO} && exit ${LINENO}
  else
    [ -n "$hostRoot" ] || usage "Please specify \"-w <from-dir>\" when running --restore"
  fi
  echo BYE ${LINENO} && exit ${LINENO}

  checkContainer $dataContainer $DW_DATA_HOST mariadb # $DW_DATA_IMAGE=mariadb?
  checkContainer $viewContainer $DW_VIEW_HOST mediawiki

  if ! $QUIET; then
    echo
    for name in dataContainer viewContainer hostRoot dataFile imageDir localSettings; do
      printf "%13s = %s\n" $name ${!name}
    done
  fi

  if $BACKUP; then

    local commandA="docker exec $dataContainer mariadb-dump --all-databases -uroot -p$DW_DB_ROOT_PASSWORD"
    local file="${hostRoot}/${dataFile}.gz"
    local commandB="gzip > $file"
    xShow "$commandA >($commandB)"
    #$command | gzip >"${hostRoot}/${dataFile}.gz"
    $commandA >($commandB)
    [ $? -ne 0 ] && abend "Error backing up database; exit status '$?'."

    local commandA="docker exec $viewContainer tar -cC $wikiRoot/$imageDir ."
    local commandB="tar -xC $hostRoot/$imageDir"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && abend "Error backing up images; exit status '$?'."

    xKute2 docker cp "$viewContainer:$wikiRoot/$localSettings" "$hostRoot/$localSettings"
    [ $? -ne 0 ] && abend "Error backing up local settings: $(getLastError)"

    echo -e "\n==> Wiki backup written to '$hostRoot' <=="

  fi

  if $RESTORE; then

    # xIn "$dataFile" docker exec -i "$dataContainer" sh -c "exec mariadb -uroot -p$MARIADB_ROOT_PASSWORD"
    local command="docker exec -i $dataContainer mariadb -uroot -p$DW_DB_ROOT_PASSWORD"
    xShow "$command < $hostRoot/${dataFile}.gz"
    $command <$hostRoot/${dataFile}.gz
    [ $? -ne 0 ] && abend "Error restoring database!"

    local commandA="tar -cC ${hostRoot}/$imageDir ."
    local commandB="docker exec --interactive $viewContainer tar -xC $wikiRoot/$imageDir"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && abend "Error restoring images: exit status '$?'"

    xKute2 docker cp "$hostRoot/$localSettings" "$viewContainer:$wikiRoot/$localSettings"
    [ $? -ne 0 ] && abend "Error backing up local settings: $(getLastError)"

    echo && echo "==> Wiki restored from '$hostRoot' <=="

  fi
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  There are no more words.
#
parseCommandLine() {
  set -- $(getOpt "$@")
  while [[ $# -gt 0 ]]; do # https://stackoverflow.com/a/14203146
    case "$1" in
    -b | --backup) # or one-liners?
      BACKUP=true
      shift
      ;;
    -D | --data-container)
      dataContainer="$2"
      shift 2
      ;;
    -f | --force)
      force=true
      ;;
    -h | --help)
      usage
      ;;
    --no-decoration)
      DECORATE=false
      shift
      ;;
    -r | --restore)
      RESTORE=true
      shift
      ;;
    -V | --view-container)
      viewContainer="$2"
      shift 2
      ;;
    -v | --verbose)
      QUIET=false
      shift
      ;;
    -w | --work-dir)
      hostRoot="$2"
      shift 2
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
#  You have to say something.
#
usage() {

  [ -n "$*" ] && echo >&2 -e "\n****  $*  ****"

  local moi=$(basename ${BASH_SOURCE[0]})

  cat >&2 <<EOT

Usage:
  $moi --backup [-w <to-dir>] [OPTIONS]
  $moi --restore -w <from-dir> [OPTIONS]

Backup and restore a DockerWiki.

Options:
  -b | --backup                  Backup database, images, and local settings
  -D | --data-container string   Override default '$(getContainer data)'
  -h | --help                    Print this usage summary
  -f | --force                   Allow backup to an existing location
       --no-decoration           Disable composer-naming emulation
  -r | --restore                 Restore database, images, and local settings
  -V | --view-container string   Override default '$(getContainer view)'
  -v | --verbose                 Display a few parameters
  -w | --work-dir string         Host directory to backup to or restore from
EOT
  exit 42
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Capua, shall I begin?
#
main "$@"

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Old notes, snippets, unit tests, etc.
#
# # Test getOpt().
# echo "main: incoming args: (" $(join ', ' "$@") ")"
# set -- $(getOpt "$@")
# echo "main: adjusted args: (" $(join ', ' "$@") ")"
# return

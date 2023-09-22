#!/usr/bin/env bash
#
#  Backup and restore tools adapted from hub pages for official
#  mediawiki and mariadb images.
#
#  This script passes cleartext passwords so is Not Secure.
#  This script requires 'bash' and 'jq'.
#
#  Try camel case for file scope hint, uppercase for globals?
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
hostRoot=                # see --work-dir
wikiRoot="/var/www/html" # docroot inside view container
dataFile=all-databases.sql
imageDir=images
localSettings=LocalSettings.php

# Defaults subject to change via command line options.
dataContainer=$(getContainer $DATA_SERVICE)
viewContainer=$(getContainer $VIEW_SERVICE)

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

  xQute12 $inspect ||
    die "Error inspecting container '$container': $(getLastError)"

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

  isDockerRunning || die "Is docker down? I cannot connect."

  parseCommandLine "$@"

  # Precedence unclear and it seems to work...
  ($BACKUP && $RESTORE) || (! $BACKUP && ! $RESTORE) &&
    usage "Please specify either --backup or --restore"

  if $BACKUP; then
    [ -n "$hostRoot" ] || hostRoot="$(getTempDir)/backup-$(date '+%y%m%d-%H%M%S')"
    for dir in "$hostRoot" "$hostRoot/$imageDir"; do
      if [ -d "$dir" ]; then
        $force || usage "Use --force to reuse working dir '$dir'"
      else
        xCute2 mkdir "$dir" || usage "Trouble creating '$dir': $(getLastError)"
      fi
    done
  else
    [ -n "$hostRoot" ] || usage "Please specify \"-w <from-dir>\" when running --restore"
    [ -d "$hostRoot" ] || usage "-w <$hostRoot> not found, nothing to restore"
  fi

  checkContainer $dataContainer $DATA_HOST mariadb # $DW_DATA_IMAGE=mariadb?
  checkContainer $viewContainer $VIEW_HOST mediawiki

  if ! $QUIET; then
    echo
    for name in dataContainer viewContainer hostRoot dataFile imageDir localSettings; do
      printf "%13s = %s\n" $name ${!name}
    done
  fi

  if $BACKUP; then

    # Backup database.
    local command="docker exec $dataContainer mariadb-dump --all-databases -uroot -p$DB_ROOT_PASSWORD"
    local file="${hostRoot}/${dataFile}.gz"
    xShow "$command | gzip > \"$file\""
    $command | gzip >"$file"
    [ $? -ne 0 ] && die "Error backing up database; exit status '$?'."

    # Backup images
    local commandA="docker exec $viewContainer tar -cC $wikiRoot/$imageDir ."
    local commandB="tar -xC $hostRoot/$imageDir"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && die "Error backing up images; exit status '$?'."

    # Save LocalSettings.php.
    xCute2 docker cp \
      "$viewContainer:$wikiRoot/$localSettings" \
      "$hostRoot/$localSettings" ||
      die "Error backing up local settings: $(getLastError)"

    echo -e "\n==> Wiki backup written to '$hostRoot' <=="

  fi

  if $RESTORE; then

    # Restore database
    local command="docker exec -i $dataContainer mariadb -uroot -p$DB_ROOT_PASSWORD"
    local file=$hostRoot/${dataFile}.gz
    xShow "gunzip \"$file\" | $command"
    gunzip "$file" | $command
    [ $? -ne 0 ] && die "Error restoring database!"

    # Restore pics.
    local commandA="tar -cC ${hostRoot}/$imageDir ."
    local commandB="docker exec --interactive $viewContainer tar -xC $wikiRoot/$imageDir"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && die "Error restoring images: exit status '$?'"

    # Restore local settings / configuration.
    xCute2 docker cp \
      "$hostRoot/$localSettings" \
      "$viewContainer:$wikiRoot/$localSettings" ||
      die "Error backing up local settings: $(getLastError)"

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
    -b | --backup)
      BACKUP=true
      shift
      ;;
    -D | --data-container)
      dataContainer="$2"
      shift 2
      ;;
    -f | --force)
      force=true
      shift
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
      hostRoot="${2%/}" # remove any trailing '/'
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

#!/usr/bin/env bash
#
#  This script can backup and restore DockerWiki:
#
#    $ ./backrest.sh --help                 # Print usage summary
#    $ ./backrest.sh --backup                 # -> ~/.DockerWiki/backup/<date>/
#    $ ./backrest.sh -bw /mydw/backup_dir/      # -> /mydw/backup_dir/<date>/
#    $ ./backrest.sh -rw /mydw/backup_dir/<date>  # <- /mydw/backup_dir/<date>
#
#  Default `backup_dir` or "working directory" may be changed in
#  `~/.DockerWiki/config`:
#
#    DW_BACKUP_DIR=/mydw/backup_dir   # Override default backup directory
#
#  - - - - - - - -
#
#  Here's a thought:
#    * Environment variables are UPPER_CASE;
#    * File scope variables are PascalCase;
#    * Function scope (local nameref) variables are camelCase.
#
#  - - - - - - - -
#
#  TODO: Write somewhere how to change account names and/or passwords
#  on a live system, then saved to backup.
#
#  This script requires 'bash' and 'jq'.
#
#  Mention JQ up front. This uses a jq tool c/o i forget.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ScriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${ScriptDir}/bootstrap.sh"

# What to do.
Backup=false
Force=false
Quiet=true
Restore=false

# Where to do it.
DataFile=$DW_DB_NAME.sql
HostRoot= # see --work-dir
ImageDir=images
LocalSettings=LocalSettings.php
WikiRoot="/var/www/html" # docroot inside view container

# Defaults subject to change via command line options.
DataContainer=$(getContainer $DW_DATA_SERVICE)
ViewContainer=$(getContainer $DW_VIEW_SERVICE)

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

  # Validate request excessively.

  ($Backup && $Restore) || (! $Backup && ! $Restore) &&
    usage "Please specify either --backup or --restore"

  if $Backup; then
    [ -n "$HostRoot" ] || HostRoot="$(getTempDir)/backup.$(date '+%y%m%d.%H%M%S')"
    for dir in "$HostRoot" "$HostRoot/$ImageDir"; do
      if [ -d "$dir" ]; then
        $Force || usage "Use --force to reuse working dir '$dir'"
      else
        xCute2 mkdir "$dir" || usage "Trouble creating '$dir': $(getLastError)"
      fi
    done
  else
    [ -n "$HostRoot" ] || usage "Please specify \"-w <from-dir>\" when running --restore"
    [ -d "$HostRoot" ] || usage "-w <$HostRoot> not found, nothing to restore"
  fi

  checkContainer $DataContainer $DW_DATA_HOST mariadb
  checkContainer $ViewContainer $DW_VIEW_HOST mediawiki

  if ! $Quiet; then
    echo
    for name in DataContainer ViewContainer HostRoot DataFile ImageDir LocalSettings; do
      printf "%13s = %s\n" $name ${!name}
    done
  fi

  # Verify credentials extensively.

  # Use may define DW_DB_USER_PASSWORD or use command line --password=xyz.
  # Else, we prompt.
  while [ -z "${DW_DB_USER_PASSWORD:-}" ]; do
    echo
    read -sp "Please enter password for user $DW_DB_USER: " DW_DB_USER_PASSWORD
    echo
  done

  if $Backup; then

    # Backup database.
    #  local command="docker exec $DataContainer mariadb-dump --all-databases -uroot -p$DB_ROOT_PASSWORD"
    local command="docker exec $DataContainer mariadb-dump"
    command="${command} -u$DW_DB_USER -p$DW_DB_USER_PASSWORD"
    command="${command} --databases $DW_DB_NAME"
    local file="${HostRoot}/${DataFile}.gz"
    xShow "$command | gzip > \"$file\""
    $command | gzip >"$file"
    [ $? -ne 0 ] && die "Error backing up database; exit status '$?'."

    # Backup images
    local commandA="docker exec $ViewContainer tar -cC $WikiRoot/$ImageDir ."
    local commandB="tar -xC $HostRoot/$ImageDir"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && die "Error backing up images; exit status '$?'."

    # Save LocalSettings.php.
    xCute2 docker cp \
      "$ViewContainer:$WikiRoot/$LocalSettings" \
      "$HostRoot/$LocalSettings" ||
      die "Error backing up local settings: $(getLastError)"

    # Make backups mostly read-only.
    command="find $HostRoot -type f -exec chmod -w {} ;"
    xCute2 $command || die "Trouble making backup mostly read-only: $(getLastError)"

    echo -e "\n==> Wiki backup written to '$HostRoot' <=="

  fi

  if $Restore; then

    # Restore database
    # local command="docker exec -i $DataContainer mariadb -uroot -p$DB_ROOT_PASSWORD"
    local command="docker exec -i $DataContainer mariadb"
    commmand="${command} -u$DW_DB_USER -p$DW_DB_USER_PASSWORD"
    die command is \"${command}\"
    local file=$HostRoot/${DataFile}.gz
    xShow "gzcat \"$file\" | $command"
    gzcat "$file" | $command
    [ $? -ne 0 ] && die "Error restoring database!"

    # Restore pics.
    local commandA="tar -cC ${HostRoot}/$ImageDir ."
    local commandB="docker exec --interactive $ViewContainer tar -xC $WikiRoot/$ImageDir"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && die "Error restoring images: exit status '$?'"

    # Restore local settings / configuration.
    xCute2 docker cp \
      "$HostRoot/$LocalSettings" \
      "$ViewContainer:$WikiRoot/$LocalSettings" ||
      die "Error backing up local settings: $(getLastError)"

    echo && echo "==> Wiki restored from '$HostRoot' <=="

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
      Backup=true
      shift
      ;;
    -D | --data-container)
      DataContainer="$2"
      shift 2
      ;;
    -f | --force)
      Force=true
      shift
      ;;
    -h | --help)
      usage
      ;;
    --no-decoration)
      DECORATE=false
      shift
      ;;
    -p | --password)
      DW_DB_USER_PASSWORD=$2
      shift 2
      ;;
    -r | --restore)
      Restore=true
      shift
      ;;
    -V | --view-container)
      ViewContainer="$2"
      shift 2
      ;;
    -v | --verbose)
      Quiet=false
      shift
      ;;
    -w | --work-dir)
      HostRoot="${2%/}" # remove any trailing '/'
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
  -p | --password string         MediaWiki DBA password
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

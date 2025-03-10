#!/usr/bin/env bash
#
#  This script can backup and restore DockerWiki:
#
#    $ ./backrest.sh --help                 # Print usage summary
#    $ ./backrest.sh --backup                 # -> ~/.DockerWiki/backup/<date>/
#    $ ./backrest.sh -bw /mydw/backup_dir/      # -> /mydw/backup_dir/<date>/
#    $ ./backrest.sh -rw /mydw/backup_dir/<date>  # <- /mydw/backup_dir/<date>
#
#  - - - - - - - -
#
#  This script requires 'bash' and 'jq'.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ScriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${ScriptDir}/bootstrap.sh"

# What to do.
Backup=false
Force=false
Quiet=true
Restore=false
Zipped=true

# Where to do it.
BackupDir=${DW_BACKUPS_DIR}/$(date '+%y%m%d.%H%M%S') # see --work-dir
DataFile=$DB_DATABASE.sql
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

  local command commandHide commandShow

  isDockerRunning || die "Is docker down? I cannot connect."

  parseCommandLine "$@"

  # Validate request excessively.

  ($Backup && $Restore) || (! $Backup && ! $Restore) &&
    usage "Please specify either --backup or --restore"

  if $Backup; then
    if test -d "$BackupDir"; then
      if $Force; then
        xCute2 chmod -R u+w $BackupDir || # Make existing backup writable.
          die "Trouble making backup writable: $(getLastError)"
      else
        usage "Use --force to reuse working dir '$BackupDir'"
      fi
    fi
    xCute2 mkdir -p "$BackupDir/$ImageDir" ||
      usage "Trouble creating '$dir': $(getLastError)"
  else
    test -n "$BackupDir" ||
      usage "Please specify \"-w <backup-dir>\" when running --restore"
    test -d "$BackupDir" ||
      usage "'--work-dir $BackupDir' must name an existing directory"
  fi

  checkContainer $DataContainer $DW_DATA_HOST mariadb
  checkContainer $ViewContainer $DW_VIEW_HOST mediawiki

  if ! $Quiet; then
    echo
    for name in DataContainer ViewContainer BackupDir DataFile ImageDir LocalSettings; do
      printf "%13s = %s\n" $name ${!name}
    done
  fi

  # Verify credentials extensively.

  while [ -z "${DB_USER_PASSWORD:-}" ]; do
    echo
    read -sp "Please enter password for user $DB_USER: " DB_USER_PASSWORD
    echo
  done

  # Backup or restore something.

  if $Backup; then

    # Backup database.

    command="docker exec $DataContainer mariadb-dump -u$DB_USER"
    commandHide="$command -p***** --databases $DB_DATABASE"
    commandShow="$command -p$DB_USER_PASSWORD --databases $DB_DATABASE"

    local file="${BackupDir}/${DataFile}"

    if $Zipped; then
      file+=".gz"
      xShow "$commandHide | gzip > \"$file\""
      $commandShow | gzip >"$file"
    else
      xShow "$commandHide > \"$file\""
      $commandShow >"$file"
    fi

    [ $? -ne 0 ] && die "Error backing up database; exit status '$?'."

    # Backup images

    local commandA="docker exec $ViewContainer tar -cC $WikiRoot/$ImageDir ."
    local commandB="tar -xC $BackupDir/$ImageDir"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && die "Error backing up images; exit status '$?'."

    # Save LocalSettings.php.

    commandA="docker exec $ViewContainer cat $LocalSettings"
    commandB="wgSecretKey hide"
    local file="$BackupDir/$LocalSettings"
    xShow "$commandA | $commandB >$file"
    $commandA | $commandB >$file || die "Error: $(getLastError)"

    # Make backups mostly read-only.

    command="find $BackupDir -type f -exec chmod -w {} ;"
    xCute2 $command || die "Trouble making backup mostly read-only: $(getLastError)"

    # Say goodnight.

    echo -e "\n==> Wiki backup written to '$BackupDir' <=="

  fi

  if $Restore; then

    # Restore database

    command="docker exec -i $DataContainer mariadb -u$DB_USER"
    commandHide="$command -p*****"
    commandShow="$command -p$DB_USER_PASSWORD"

    local file="$BackupDir/${DataFile}"

    if test -f $file; then # unzipped
      xShow "cat \"$file\" | $commandHide"
      cat "$file" | $commandShow
    else #zipped
      xShow "gzcat \"$file\" | $commandHide"
      gzcat "$file" | $commandShow
    fi

    [ $? -ne 0 ] && die "Error restoring database!"

    # Restore pics.

    local commandA="tar -cC ${BackupDir}/$ImageDir ."
    local commandB="docker exec --interactive $ViewContainer tar -xC $WikiRoot/$ImageDir"
    xShow "$commandA | $commandB"
    $commandA | $commandB
    [ $? -ne 0 ] && die "Error restoring images: exit status '$?'"

    # Restore LocalSettings.php and its famous secret key.

    local inFile="$BackupDir/$LocalSettings"
    local tmpFile="$(getTempDir)/$LocalSettings"
    xShow "cat $inFile | wgSecretKey show >$tmpFile"
    cat "$inFile" | wgSecretKey show >"$tmpFile" || die "Error: $(getLastError)"
    xCute2 docker cp "$tmpFile" "$ViewContainer:$WikiRoot/" &&
      xCute2 rm "$tmpFile" || die "Error: $(getLastError)"

    # Fix all settings to match current project context.

    xCute configure.sh -v || die "Error: $(getLastError)"

    # Say goodnight.

    echo && echo "==> Wiki restored from '$BackupDir' <=="

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
      DB_USER_PASSWORD=$2
      shift 2
      ;;
    -r | --restore)
      Restore=true
      shift
      ;;
    -u | --unzipped)
      Zipped=false
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
      BackupDir="${2%/}" # remove any trailing '/' (but '/' => '' ...)
      test -z "$BackupDir" && BackupDir=.
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
  -u | --unzipped                Leave db.sql; don't gzip to db.sql.gz.
  -V | --view-container string   Override default '$(getContainer view)'
  -v | --verbose                 Display a few parameters
  -w | --work-dir string         Backup directory on host
EOT
  exit 42
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Capua, shall I begin?
#
main "$@"

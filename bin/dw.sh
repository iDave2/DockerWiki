#!/usr/bin/env bash
#
#  DockerWiki wrapper under construction.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ScriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${ScriptDir}/bootstrap.sh"

url=http://localhost:8080/

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
backup() {
  echo && echo "==> Backing up $DW_SITE <=="
  local backupDir=${MY_BACKUP_DIR} # Secret defined in DW_USER_CONFIG
  test -n $backupDir && backupDir="--work-dir ${backupDir}"
  local command="${ScriptDir}/backrest.sh --backup --force --unzipped $backupDir"
  xShow $command
  $command
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
main() {

  isDockerRunning && echo "Docker is running" || echo "Docker is not running"

  parseCommandLine "$@"

  # Make sure docker is listening.

  weOpenedDocker=false
  if ! isDockerRunning; then # Disable auto-dashboard in Settings
    xCute2 open -a Docker || die "Error: $(getLastError)"
    for ((timer = 10; timer > 0; --timer)); do
      sleep 1 # Next isDockerRunning appears to wait...
      isDockerRunning && weOpenedDocker=true && break
    done
    $weOpenedDocker || die "Error: cannot start docker"
  fi

  # Make sure containers are running.

  xCute docker start wiki-data-1 wiki-view-1
  isWikiUp=false
  for ((timer = 10; timer > 0; --timer)); do
    xQute2 curl -sS $url && isWikiUp=true && break
    sleep 1
  done
  $isWikiUp || die "Error: $(getLastError)"

  # Open browser page.

  xCute open $url

  # Make an unzipped backup, for git

  backup || die "ERROR: backup failed"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
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
#  Summarize usage on request or when command line does not compute.
#
usage() {
  if [ -n "$*" ]; then
    echo -e "\n***  $@  ***" >&2
  fi
  cat >&2 <<EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

[Fix old cake usage].

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
main "$@"

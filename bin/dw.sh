#!/usr/bin/env bash
#
#  DockerWiki wrapper for everyday use, this program starts docker, starts
#  wiki containers, opens a browser to website, and takes a backup.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Resolve links completely or find nothing.
ScriptDir=$(dirname -- $(realpath -- ${BASH_SOURCE[0]}))
source "${ScriptDir}/bootstrap.sh"

# MY_BACKUP_DIR could be in DW_USER_CONFIG, for example.
BackupDir=${MY_BACKUP_DIR:-$DW_BACKUPS_DIR/$(date '+%y%m%d.%H%M%S')}

SiteURL=http://localhost:8080/

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
backup() {
  echo && echo "==> Backing up $MW_SITE <=="
  xCute2 backrest.sh --backup --force --unzipped --work-dir $BackupDir ||
    die "Error: $(getLastError)"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
main() {

  echo && isDockerRunning &&
    echo "Docker is running" ||
    echo "Docker is not running"

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

  # Make sure containers are chatty.

  xCute2 docker start wiki-data-1 wiki-view-1 && waitForView $SiteURL ||
    die "Trouble accessing $SiteURL: $(getLastError)"

  # Open browser page.

  xCute open $SiteURL

  # Make an unzipped backup

  backup || die "ERROR: backup failed"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
parseCommandLine() {
  set -- $(getOpt "$@")
  while [[ $# -gt 0 ]]; do # https://stackoverflow.com/a/14203146
    case "$1" in
    -h | --help)
      usage
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
usage() {
  if [ -n "$*" ]; then
    echo -e "\n***  $@  ***" >&2
  fi
  cat >&2 <<EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Start DockerWiki and take a backup.

Options:
  -h | --help               Print this usage summary
EOT
  exit 1
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
main "$@"

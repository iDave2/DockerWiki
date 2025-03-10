#!/usr/bin/env bash
#
#  This program is called whenever a LocalSettings.php is created or
#  restored in the MediaWiki container. It sets MediaWiki's internal
#  configuration variables $wgXyz to match values in this project
#  environment (i.e., .env, DW_USER_CONFIG, etc.).
#
#  Here is an example circa March 2025,
#
#      $wgDBname        = "mediawiki";
#      $wgDBpassword    = "changeThis";
#      $wgDBserver      = "wiki-data-1";
#      $wgDBuser        = "WikiDBA";
#      $wgEnableUploads = true;
#      $wgSecretKey     = "<64 hex digits>";
#      $wgServer        = "http://localhost:8080"; # ?
#      $wgSitename      = "DockerWiki";
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ScriptDir=$(dirname -- $(realpath -- ${BASH_SOURCE[0]}))
source "${ScriptDir}/bootstrap.sh"

HostSettings="$DW_TEMP_DIR/settings.php" Keep=false
SecretKey=$(perl -we "print map { ('0'..'9','a'..'f')[int(rand(16))] } 1..64")
ViewSettings="$DW_VIEW_HOST:/var/www/html/LocalSettings.php"
Verbose=false

# These little functions are nice for hide and show.
Stars="******"
login() { echo docker exec $DW_DATA_HOST mariadb -p"${1:-$Stars}"; }

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
fixData() {

  heading "FIX DATABASE"

  setPassword() { echo "SET PASSWORD FOR '$1'@'$2' = PASSWORD('${3:-$Stars}')"; }

  updateFile() { echo docker exec $DW_DATA_HOST bash -c \
    "echo '${2:-$Stars}' >/root/${1:-$Stars}"; }

  local host='' hosts=()

  if test -n ${OldRootPassword:-''}; then
    hosts=($(getHosts root $OldRootPassword)) || dieLastError
    # echo "root hosts = ($(join ', ' ${hosts[@]}))."
    for host in "${hosts[@]}"; do # hopefully not multiple hosts for root...
      xShow "$(login)" -e \"$(setPassword root $host)\"
      xQute2 $(login $OldRootPassword) \
        -e "$(setPassword root $host $DB_ROOT_PASSWORD)" || dieLastError
    done
    xShow $(updateFile $DB_ROOT_PASSWORD_FILE)
    xQute2 $(updateFile $DB_ROOT_PASSWORD_FILE $DB_ROOT_PASSWORD) ||
      dieLastError
  fi

  hosts=($(getHosts $DB_USER))
  # echo "$DB_USER hosts = ($(join ', ' ${hosts[@]}))."
  for host in "${hosts[@]}"; do
    xShow "$(login)" -e \"$(setPassword $DB_USER $host)\"
    xQute2 $(login $DB_ROOT_PASSWORD) \
      -e "$(setPassword $DB_USER $host $DB_USER_PASSWORD)" || dieLastError
  done
  xShow $(updateFile $DB_USER_PASSWORD_FILE)
  xQute2 $(updateFile $DB_USER_PASSWORD_FILE $DB_USER_PASSWORD) ||
    dieLastError
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
fixImages() { # view:/var/www/html/images
  heading "FIX IMAGES"
  local ug='www-data' # TODO: hard-coded user:group ?
  xCute2 docker exec $DW_VIEW_HOST chown -R $ug:$ug images &&
    xCute2 docker exec $DW_VIEW_HOST find images -type f -exec chmod u+w {} \; ||
    dieLastError
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
fixSettings() { # view:/var/www/html/LocalSettings.php

  heading "FIX SETTINGS"

  # Fix LocalSettings.php.

  xCute2 docker cp $ViewSettings $HostSettings && chmod 644 $HostSettings ||
    dieLastError

  perl -i.bak -pwe '
  s {^\s*(\$wgDBname)\s*=.*}        {$1 = "'$DB_DATABASE'";} ;
  s {^\s*(\$wgDBpassword)\s*=.*}    {$1 = "'$DB_USER_PASSWORD'";} ;
  s {^\s*(\$wgDBserver)\s*=.*}      {$1 = "'$DW_DATA_HOST'";} ;
  s {^\s*(\$wgDBuser)\s*=.*}        {$1 = "'$DB_USER'";} ;
  s {^\s*(\$wgEnableUploads)\s*=.*} {$1 = '$MW_ENABLE_UPLOADS';} ;
  s {^\s*(\$wgSecretKey)\s*=.*}     {$1 = "'$SecretKey'";} ;
  s {^\s*(\$wgServer)\s*=.*}        {$1 = "'$(getServer)'";} ;
  s {^\s*(\$wgSitename)\s*=.*}      {$1 = "'$MW_SITE'";} ;
  ' $HostSettings

  ! $Verbose || xCute diff $HostSettings.bak $HostSettings
  xCute2 docker cp $HostSettings $ViewSettings || dieLastError
  $Keep || xCute rm -f $HostSettings{,.bak} || dieLastError

  # Fix $MW_ADMIN aka 'WikiAdmin'

  cmd() { echo docker exec $DW_VIEW_HOST maintenance/run changePassword \
    --user=$MW_ADMIN --password="${1:-$Stars}"; }
  xShow "$(cmd)"
  xQute2 $(cmd $MW_ADMIN_PASSWORD) || dieLastError
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Return hosts associated with a mysql.user username.
#
getHosts() {
  local user=${1:-''} password=${2:-$DB_ROOT_PASSWORD}
  sql() { echo "SELECT host FROM mysql.user WHERE user = '${1:-$Stars}'"; }
  xQute2 $(login $password) -N -e "$(sql $user)" || dieLastError
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
heading() {
  local dashes="########"
  echo && echo "$dashes  $*  $dashes"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
main() {
  parseCommandLine "$@"
  fixData && fixImages && fixSettings &&
    xCute2 docker restart $DW_VIEW_HOST || dieLastError
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
parseCommandLine() {
  set -- $(getOpt "$@")
  while test $# -gt 0; do # https://stackoverflow.com/a/14203146
    case "$1" in
    -h | --help)
      usage
      ;;
    -k | --keep)
      Keep=true
      shift
      ;;
    -p | --password)
      OldRootPassword=${2:-''}
      shift 2
      ;;
    -v | --verbose)
      Verbose=true
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
usage() {
  if [ -n "$*" ]; then
    echo -e "\n***  $@  ***" >&2
  fi
  cat >&2 <<EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS]

Configure containers with local project settings.

Options:
  -h | --help               Print this usage summary
  -k | --keep               Keep intermediate files
  -p | --password string    Old DB_ROOT_PASSWORD
  -v | --verbose            Print diffs caused by filter
EOT
  exit 1
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
main "$@"

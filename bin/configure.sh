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
#      $wgSecretKey     = "%%wgSecretKey%%";
#      $wgServer        = "http://localhost:8080"; # ?
#      $wgSitename      = "DockerWiki";
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ScriptDir=$(dirname -- $(realpath -- ${BASH_SOURCE[0]}))
source "${ScriptDir}/bootstrap.sh"

declare -A C=() # To boldly go...see fixPasswords()

File="$DW_TEMP_DIR/config.php" Keep=false

SecretKey=$(perl -we "print map { ('0'..'9','a'..'f')[int(rand(16))] } 1..64")

Server=$(
  host=127.0.0.1 map=($(echo $MW_PORTS | tr ':' ' ')) port=${map[-2]}
  if test ${#map[@]} -gt 2 -a -n "${map[-3]}"; then
    host=${map[-3]}
  fi
  echo "http://$host:$port"
)

Settings=/var/www/html/LocalSettings.php

Verbose=false

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

  heading "WAIT FOR DATA AND VIEW TO WAKE UP"

  waitForData 10 || die "Error: Cannot talk to MariaDB"
  waitForView $Server 15 || die "Error: Cannot talk to MediaWiki"

  fixSettings && fixPasswords && fixImages && flushViewCache
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
fixImages() { # view:/var/www/html/images

  heading "FIX IMAGES"

  local ug='www-data' # TODO: hard-coded user:group ?

  xCute2 docker exec $DW_VIEW_HOST chown -R $ug:$ug images &&
    xCute2 docker exec $DW_VIEW_HOST find images -type f -exec chmod u+w {} \; ||
    die "Error: $(getLastError)"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
fixPasswords() { # Fix passwords outside of LocalSettings.php

  heading "FIX PASSWORDS"

  local stars="******"

  # Fix $DB_USER aka $wgDBuser aka 'WikiDBA'

  cmd() { echo docker exec $DW_DATA_HOST mariadb -p"${1:-$stars}"; }
  sql() { echo "SET PASSWORD FOR '$DB_USER'@'%' = PASSWORD('${1:-$stars}')"; }

  xShow "$(cmd)" -e \"$(sql)\"
  xQute2 $(cmd $DB_ROOT_PASSWORD) -e "$(sql $DB_USER_PASSWORD)" ||
    die "Error: $(getLastError)"

  # Fix $MW_ADMIN aka 'WikiAdmin'

  cmd() { echo docker exec $DW_VIEW_HOST maintenance/run changePassword \
    --user=$MW_ADMIN --password="${1:-$stars}"; }

  xShow "$(cmd)"
  xQute2 $(cmd $MW_ADMIN_PASSWORD) || die "Error: $(getLastError)"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
fixSettings() { # view:/var/www/html/LocalSettings.php

  heading "FIX SETTINGS"

  xCute2 docker cp $DW_VIEW_HOST:$Settings $File && chmod 644 $File ||
    die "Error: $(getLastError)"

  perl -i.bak -pwe '
  s {^\s*(\$wgDBname)\s*=.*}        {$1 = "'$DB_DATABASE'";} ;
  s {^\s*(\$wgDBpassword)\s*=.*}    {$1 = "'$DB_USER_PASSWORD'";} ;
  s {^\s*(\$wgDBserver)\s*=.*}      {$1 = "'$DW_DATA_HOST'";} ;
  s {^\s*(\$wgDBuser)\s*=.*}        {$1 = "'$DB_USER'";} ;
  s {^\s*(\$wgEnableUploads)\s*=.*} {$1 = '$MW_ENABLE_UPLOADS';} ;
  s {^\s*(\$wgSecretKey)\s*=.*}     {$1 = "'$SecretKey'";} ;
  s {^\s*(\$wgServer)\s*=.*}        {$1 = "'$Server'";} ;
  s {^\s*(\$wgSitename)\s*=.*}      {$1 = "'$MW_SITE'";} ;
  ' $File

  ! $Verbose || xCute diff $File.bak $File

  xCute2 docker cp $File $DW_VIEW_HOST:$Settings || die "Error: $(getLastError)"

  $Keep || xCute rm -f $File{,.bak} || die "Error: $(getLastError)"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
flushViewCache() { # that is, restart MediaWiki

  heading "FLUSH VIEW CACHE"

  xCute2 docker restart $DW_VIEW_HOST || die "Error: $(getLastError)"
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
  -h | --help       Print this usage summary
  -k | --keep       Keep intermediate files
  -v | --verbose    Print diffs caused by filter
EOT
  exit 1
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
main "$@"

#!/usr/bin/env bash
#
#  This program is called whenever a LocalSettings.php is written to the
#  MediaWiki container. This filter sets $wg variables to match whatever
#  is defined in this project's environment settings. For example,
#
#      $wgDBname     = "mediawiki";
#      $wgDBpassword = "changeThis";
#      $wgDBserver   = "wiki-data-1";
#      $wgDBuser     = "WikiDBA";
#      $wgSecretKey  = "%%wgSecretKey%%";
#      $wgServer     = "http://localhost:8080"; # ?
#      $wgSitename   = "DockerWiki";
#
#  Extensions are not managed here.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ScriptDir=$(dirname -- $(realpath -- ${BASH_SOURCE[0]}))
source "${ScriptDir}/bootstrap.sh"

File="$DW_TEMP_DIR/config.php" Settings=/var/www/html/LocalSettings.php

xCute2 docker cp $DW_VIEW_HOST:$Settings $File || die "Error: $(getLastError)"

SecretKey=$(perl -we "print map { ('0'..'9','a'..'f')[int(rand(16))] } 1..64")

host=127.0.0.1 map=($(echo $MW_PORTS | tr ':' ' ')) port=${map[-2]}
if test ${#map[@]} -gt 2 -a -n "${map[-3]}"; then
  host=${map[-3]}
fi
Server="http://$host:$port"

perl -i.bak -pwe '
  s {^\s*(\$wgDBname)\s*=.*}     {$1 = "'$DB_DATABASE'";} ;
  s {^\s*(\$wgDBpassword)\s*=.*} {$1 = "'$DB_USER_PASSWORD'";} ;
  s {^\s*(\$wgDBserver)\s*=.*}   {$1 = "'$DW_DATA_HOST'";} ;
  s {^\s*(\$wgDBuser)\s*=.*}     {$1 = "'$DB_USER'";} ;
  s {^\s*(\$wgSecretKey)\s*=.*}  {$1 = "'$SecretKey'";} ;
  s {^\s*(\$wgServer)\s*=.*}     {$1 = "'$Server'";} ;
  s {^\s*(\$wgSitename)\s*=.*}   {$1 = "'$MW_SITE'";} ;
  ' $File

xCute2 docker cp $File $DW_VIEW_HOST:$Settings || die "Error: $(getLastError)"

if test ${1:-""} != "-k" -a ${1:-""} != "--keep"; then
  xCute2 rm $File{,.bak} || die "Error: $(getLastError)"
fi
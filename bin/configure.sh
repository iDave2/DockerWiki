#!/usr/bin/env bash
#
#  This program is called whenever a LocalSettings.php is written to the
#  MediaWiki container. This filter sets $wg variables to match whatever
#  is defined in this project environment settings. For example,
#
#      $wgDBname     = "mediawiki";
#      $wgDBpassword = "changeThis";
#      $wgDBserver   = "wiki-data-1";
#      $wgSecretKey  = "%%wgSecretKey%%";
#      $wgServer     = "http://localhost:8080"; # ?
#      $wgSitename   = "DockerWiki";
#      $wgDBuser     = "WikiDBA";
#
#  Extensions are not managed here. Yet.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Resolve links completely or die trying.
ScriptDir=$(dirname -- $(realpath -- ${BASH_SOURCE[0]}))
source "${ScriptDir}/bootstrap.sh"

File="$DW_TEMP_DIR/config.php"
LS=LocalSettings.php
SecretKey=$(perl -we "print map { ('0'..'9','a'..'f')[int(rand(16))] } 1..64")

xCute2 docker cp $DW_VIEW_HOST:/var/www/html/$LS $File ||
  die "Error: $(getLastError)"

perl -i.bak -pwe '
  s {^\s*(\$wgDBname)\s*=.*}     {$1 = "'$DB_DATABASE'";} ;
  s {^\s*(\$wgDBpassword)\s*=.*} {$1 = "'$DB_USER_PASSWORD'";} ;
  s {^\s*(\$wgSecretKey)\s*=.*}  {$1 = "'$SecretKey'";} ;
  ' $File

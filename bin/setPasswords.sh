#!/usr/bin/env bash
#
#  This script sets the three passwords given by their build environment
#  variables:
#
#    - DW_MW_ADMIN_PASSWORD
#    - DW_DB_ROOT_PASSWORD
#    - DW_DB_USER_PASSWORD
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Resolve links completely or find nothing.
ScriptDir=$(dirname -- $(realpath -- ${BASH_SOURCE[0]}))
source "${ScriptDir}/bootstrap.sh"

# SET PASSWORD [FOR user] =
#     {
#         PASSWORD('some password')
#       | OLD_PASSWORD('some password')
#       | 'encrypted password'
#     }

# php maintenance/run.php changePassword --user Foo --password IamPassword


####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
# MediaWiki DBA, aka DW_DB_USER, aka wgDBuser

xCute2 docker exec wiki-data-1 mariadb -p$DW_DB_ROOT_PASSWORD -e \
  "SET PASSWORD FOR '$DW_DB_USER'@'%' = PASSWORD('$DW_DB_USER_PASSWORD')" ||
  die "Error: $(getLastError)"

# RUN set -eu; \
#   key=$(perl -we "print map { ('0'..'9','a'..'f')[int(rand(16))] } 1..64"); \
#   perl -i.bak -pwe "s|%%wgSecretKey%%|$key|" LocalSettings.php
# $wgDBpassword = "changeThis";

xCute2 docker exec wiki-view-1 perl -i.bak -pwe \
  "s|^(\s*\$wgDBpassword\s*=\s*).*)|$1\"$DW_DB_USER_PASSWORD\";|" \
  LocalSettings.php ||
  die "Error: $(getLastError)"


####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
# MediaWiki admin

xCute2 docker exec wiki-view-1 maintenance/run changePassword \
  --user $DW_MW_ADMIN --password $DW_MW_ADMIN_PASSWORD ||
  die "Error: $(getLastError)"


####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
# MariaDB root?

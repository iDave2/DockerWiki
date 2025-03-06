#!/usr/bin/env bash
#
#  This script sets passwords for the two MediaWiki accounts as
#  specified in the current environment settings:
#
#    - MW_ADMIN_PASSWORD  # Wiki site administrator password
#    - DB_ROOT_PASSWORD   # Wiki database administrator password
#
#  The MariaDB root password is not easily changed without knowing its
#  current value. If known, it can be changed using the SQL below; if
#  not known, one may Backup, Rebuild, and Restore using values from
#  project environment (.env etc.).
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Resolve links completely or find nothing.
ScriptDir=$(dirname -- $(realpath -- ${BASH_SOURCE[0]}))
source "${ScriptDir}/bootstrap.sh"

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  MediaWiki DBA, aka DB_USER, aka wgDBuser
#
xCute2 docker exec wiki-data-1 mariadb -p$DB_ROOT_PASSWORD -e \
  "SET PASSWORD FOR '$DB_USER'@'%' = PASSWORD('$DB_USER_PASSWORD')" ||
  die "Error: $(getLastError)"

xCute2 docker exec wiki-view-1 perl -i.bak -pwe \
  's|^(\s*\$wgDBpassword\s*=\s*).*|$1\"'$DB_USER_PASSWORD'\";|' \
  LocalSettings.php || die "Error: $(getLastError)"

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  MediaWiki admin
#
xCute2 docker exec wiki-view-1 maintenance/run changePassword \
  --user $MW_ADMIN --password $MW_ADMIN_PASSWORD ||
  die "Error: $(getLastError)"

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Flush MediaWiki cache before new passwords take.
#
xCute2 docker restart wiki-view-1 || die "Error: $(getLastError)"

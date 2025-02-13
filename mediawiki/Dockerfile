#  syntax = docker/dockerfile:1
#
#  FAQ: Does restore fail if passwords changed since last backup?
#  ANS: Probably. You might need some DBA action. See refs below.
#
#  FAQ: So we need to keep build-time passwords in sync with whatever
#       browser changes are made?
#  ANS: A better solution is wanted. Creating frequent backups is
#       recommended. Now go to your room and stop asking questions.
#
#  FAQ: What about restore from scratch vs restore over working system?
#  ANS: We will get back to you ASAP.
#
#  Also see:
#    https://stackoverflow.com/a/79156231;
#    https://hub.docker.com/_/mediawiki;
#    https://www.mediawiki.org/wiki/Manual:Install.php;
#    https://www.mediawiki.org/wiki/Manual:Installing_MediaWiki.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ARG VERSION=default

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  See https://stackoverflow.com/a/60820156.
#
FROM mediawiki:1.43 AS view

# Tony is Maria's boyfriend.
ARG TONY=/root


####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Default image requires passwords for the new wiki & database.
#  These files are used by wiki's command-line installer.
#
FROM view AS view-branch-default
COPY --chmod=400 dbpassfile passfile $TONY/


####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Restored images require an existing wiki -- a backup -- for input.
#
FROM view AS view-branch-restore
WORKDIR /var/www/html
COPY images images/
COPY LocalSettings.php ./

# Rewrite secret key if requested.
# TODO: This was motivated by a git warning years ago. Is it still needed?
#       LocalSettings also has clear passwords...
RUN set -eu; \
  key=$(perl -we "print map { ('0'..'9','a'..'f')[int(rand(16))] } 1..64"); \
  perl -i.bak -pwe "s|%%wgSecretKey%%|$key|" LocalSettings.php


####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Select final image from choices above.
#
FROM view-branch-${VERSION} AS final

#  Original MediaWiki entry point remains active.

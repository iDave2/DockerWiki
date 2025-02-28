#  syntax = docker/dockerfile:1
#
#  MediaWiki Dockerfile
#
#  Also see:
#    https://stackoverflow.com/a/79156231;
#    https://stackoverflow.com/a/60820156;
#    https://hub.docker.com/_/mediawiki;
#    https://www.mediawiki.org/wiki/Manual:Install.php;
#    https://www.mediawiki.org/wiki/Manual:Installing_MediaWiki;
#    https://github.com/moby/moby/issues/22832.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ARG VERSION=cli

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM mediawiki:1.43 AS view

# Tony is Maria's boyfriend.
ARG TONY=/root

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM view AS view-branch-web

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM view AS view-branch-cli
COPY --chmod=400 dbpassfile passfile $TONY/

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM view AS view-branch-restore
WORKDIR /var/www/html
COPY images images/
COPY LocalSettings.php ./
ARG CACHE_DATE=250228.132315
RUN set -eu; \
  key=$(perl -we "print map { ('0'..'9','a'..'f')[int(rand(16))] } 1..64"); \
  perl -i.bak -pwe "s|%%wgSecretKey%%|$key|" LocalSettings.php

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM view-branch-${VERSION} AS final

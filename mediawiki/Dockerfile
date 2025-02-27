#  syntax = docker/dockerfile:1
#
#  MediaWiki Dockerfile
#
#  Also see:
#    https://stackoverflow.com/a/79156231;
#    https://stackoverflow.com/a/60820156;
#    https://hub.docker.com/_/mediawiki;
#    https://www.mediawiki.org/wiki/Manual:Install.php;
#    https://www.mediawiki.org/wiki/Manual:Installing_MediaWiki.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Tony is Maria's boyfriend and default container includes cli install.
ARG TONY=/root
ARG VERSION=cli

FROM mediawiki:1.43 AS view

FROM view AS view-branch-web

FROM view AS view-branch-cli
COPY --chmod=400 dbpassfile passfile $TONY/

FROM view AS view-branch-restore
WORKDIR /var/www/html
COPY images images/
COPY LocalSettings.php ./

FROM view-branch-${VERSION} AS final

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

FROM mediawiki:1.46 AS view

## ADD --pull TO BUILDS WHEN USING HARDENED IMAGES.
## DOCKER HARDENED IMAGES QUICK-ACCESS VIA dhi.io.

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

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM view-branch-${VERSION} AS final
RUN a2enmod headers
COPY ./docker-php.conf /etc/apache2/conf-available/
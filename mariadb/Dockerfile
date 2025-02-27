#  syntax = docker/dockerfile:1
#  check  = skip=SecretsUsedInArgOrEnv
#
#  Dockerfile for yet another MariaDB.
#
#  Also see:
#    https://stackoverflow.com/a/79156231
#    https://hub.docker.com/_/mariadb/;
#    https://mariadb.com/kb/en/mariadb-server-docker-official-image-environment-variables/;
#    https://www.youtube.com/watch?v=6Bj5uyDe-hM.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ARG VERSION=cli

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  See https://stackoverflow.com/a/60820156.
#
FROM mariadb:11.6 AS data

# I just met a girl.
ARG MARIA=/root

# Any MariaDB requires at least this.
ENV MARIADB_ROOT_PASSWORD_FILE="$MARIA/mariadb-root-password-file"
COPY --chmod=400 mariadb-root-password-file $MARIA/

# Root localhost-only?.
# ARG MARIADB_ROOT_HOST
# ENV MARIADB_ROOT_HOST=$MARIADB_ROOT_HOST

# MariaDB kindly sets up a user and database for us.
# Configure something for MediaWiki.
# ARG MARIADB_DATABASE
# ENV MARIADB_DATABASE=$MARIADB_DATABASE
# ARG MARIADB_USER
# ENV MARIADB_USER=$MARIADB_USER

# Place custom initialization steps inside /docker-entrypoint-initdb.d.
COPY ./20-noop.sh /docker-entrypoint-initdb.d/


# ENV MARIADB_PASSWORD_FILE="$MARIA/mariadb-password-file"
# COPY --chmod=400 mariadb-password-file $MARIA/


####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Default image uses this endpoint.
#
FROM data AS data-branch-web

FROM data AS data-branch-cli
COPY --chmod=500 mariadb-show-databases $MARIA/

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Restored images require an existing database, a backup.
#
FROM data AS data-branch-restore
COPY $MARIADB_DATABASE.sql.gz /docker-entrypoint-initdb.d/


####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Select final image from choices above.
#
FROM data-branch-${VERSION} AS final

# Original MariaDB entry point remains active.

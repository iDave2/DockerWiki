#  syntax = docker/dockerfile:1
#  check  = skip=SecretsUsedInArgOrEnv
#
#  Dockerfile for yet another MariaDB.
#
#  Also see:
#    https://stackoverflow.com/a/79156231;
#    https://stackoverflow.com/a/60820156;
#    https://hub.docker.com/_/mariadb/;
#    https://mariadb.com/kb/en/mariadb-server-docker-official-image-environment-variables/;
#    https://www.youtube.com/watch?v=6Bj5uyDe-hM.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ARG VERSION=cli

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM mariadb:11.6 AS data

# I just met a girl.
ARG MARIA=/root

# Arguments available to every stage, even if not used.
ARG MARIADB_ROOT_HOST
ARG MARIADB_DATABASE
ARG MARIADB_USER

# Every MariaDB image requires root credentials to get going.
ENV MARIADB_ROOT_PASSWORD_FILE="$MARIA/mariadb-root-password-file"
COPY --chmod=400 mariadb-root-password-file $MARIA/

# Test /docker-entrypoint-initdb.d mechanism.
COPY ./20-noop.sh /docker-entrypoint-initdb.d/

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM data AS data-branch-web

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM data AS data-branch-cli

# Increase security.
ENV MARIADB_ROOT_HOST=$MARIADB_ROOT_HOST

# Leverage MariaDB startup to create an application (MediaWiki) database
# and an owner of that database different from root.
ENV MARIADB_DATABASE=$MARIADB_DATABASE
ENV MARIADB_USER=$MARIADB_USER
ENV MARIADB_PASSWORD_FILE="$MARIA/mariadb-password-file"
COPY --chmod=400 mariadb-password-file $MARIA/
COPY --chmod=500 mariadb-show-databases $MARIA/

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM data-branch-cli AS data-branch-restore
COPY $MARIADB_DATABASE.sql.gz /docker-entrypoint-initdb.d/

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM data-branch-${VERSION} AS final

#
#  idave2/mariadb image generator
#
#  See '.env' for environment defaults.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

FROM mariadb:10.11 AS data

# Root login instructions using cleartext password.
ARG MARIADB_ROOT_PASSWORD
ENV MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD

# MariaDB hash method leaves no cleartext password inside container.
# SELECT PASSWORD('changeThis') gives the hash below.
# ARG MARIADB_ROOT_PASSWORD_HASH
# ENV MARIADB_ROOT_PASSWORD_HASH=$MARIADB_ROOT_PASSWORD_HASH

# Limit root to local access.
ARG MARIADB_ROOT_HOST
ENV MARIADB_ROOT_HOST=$MARIADB_ROOT_HOST

# MariaDB kindly sets up a user and database for us.
# Configure something for MediaWiki.
ARG MARIADB_DATABASE
ENV MARIADB_DATABASE=$MARIADB_DATABASE
ARG MARIADB_USER
ENV MARIADB_USER=$MARIADB_USER
# ARG MARIADB_PASSWORD
# ENV MARIADB_PASSWORD=$MARIADB_PASSWORD
ARG MARIADB_PASSWORD_HASH
ENV MARIADB_PASSWORD_HASH=$MARIADB_PASSWORD_HASH

# Place custom initialization steps inside /docker-entrypoint-initdb.d.
COPY ./50-noop.sh /docker-entrypoint-initdb.d
COPY ./70-initdb.sql.gz /docker-entrypoint-initdb.d

# Original MariaDB entry point remains active.

#!/bin/sh
#
# This MariaDB initialization script does nothing but verify that it runs
# when dropped into container's '/docker-entrypoint-initdb.d/' folder as
# advertised on https://hub.docker.com/_/mariadb.

_join() { # https://stackoverflow.com/a/17841619
  c="" d="$1" r=""; shift
  for t in "$@"; do r="$r$c$t"; c=$d; done # or 'echo -n "$c$t"'
  echo $r
}

echo "\n  my entry point args:" [ $(_join ', ' "$0" "$@") ]

# bash
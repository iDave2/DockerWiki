#!/bin/sh
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  This MariaDB initialization script runs once when a MariaDB container
#  is first started.  A "temporary" database service is running when this
#  script begins; after this runs, MariaDB shuts down and restarts proper
#  with whatever mess we made here.
#
#  Place this script in '/docker-entrypoint-initdb.d/' to activate.
#  See https://hub.docker.com/_/mariadb for full story.

_join() { # https://stackoverflow.com/a/17841619
  c="" d="$1" r=""; shift
  for t in "$@"; do r="$r$c$t"; c=$d; done # or 'echo -n "$c$t"'
  echo $r
}

echo "\n  [My] entry point args:" [ $(_join ', ' "$0" "$@") ]

# Uncomment this to pause and look around.
# bash
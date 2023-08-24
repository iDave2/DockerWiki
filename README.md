# DockerWiki

This project is an implementation of the multi-container pattern outlined
in Docker Docs'
[Getting Started](https://docs.docker.com/get-started/07_multi_container/)
guide.
The audience might be developers or students learning Docker or researching
this environment for, I don't know, for the next Mars expedition.
If you want to use Docker + LAMP for business, please find similar projects
from [Bitnami](https://hub.docker.com/r/bitnami/mediawiki) or organizations
whose context includes strong security, support, and all the things a
business needs to run.

A summary of what is here:

- `bin/actionAPI.sh`: MediaWiki (MW) action API tests
- `bin/backrest.sh`: simple backup and restore starter kit
- `bin/cake.sh`: build and run makefile for `docker`
- `.env`: build and runtime configuration variables
- `.envData`: just MariaDB runtime environment
- `compose.yaml`: build and run makefile for `docker compose`
- `config.yaml`: run-only compose file for Docker Hub launch
- `setEnv.sh`: shortcuts to simplify development

## Builds

If you source `setEnv.sh`,
```
$ source setEnv.sh
alias br="bin/backrest.sh"
alias cake="bin/cake.sh"
alias d=docker
alias dc="docker compose"
```
then you can build one or both images using Docker files,
```
$ cake     # create everything
$ cake -k  # destroy everything
```
or you can build and run their Docker Compose stack-of-images,
```
$ dc up -d [--build]      # create everything
$ dc down -v --rmi local  # destroy almost everything
```
Remember to backup new important data before (accidentally) blowing away its volume!

## Backups

The database container is named `data` when run using Docker; it is named `wiki-data-1` when started with Docker Compose. Enter one of these names when backing up the database volume,
```
$ br --backup wiki-data-1  # dumps DB into ./all-databases.sql
```

ADD (and test) RESTORE EXAMPLE

Latest images are pushed to [Docker Hub](https://hub.docker.com/u/idave2) and no CI is configured (yet).

## OATH and OAuth

[Open Authentication](https://en.wikipedia.org/wiki/Initiative_for_Open_Authentication)
(i.e., two-factor login) works (although it might give new users more time to
read instructions and save all those restore keys) and can be activated in
user preferences.
If wiki administrator is somehow locked out, deleting her record from database
table `mediawiki.oathauth_users` may deactivate her two-factor login.
Also review MediaWiki's
[documentation](https://www.mediawiki.org/wiki/Extension:OATHAuth).

[Open Authorization](https://en.wikipedia.org/wiki/OAuth) may not be
ready until [MediaWiki 1.41](https://www.mediawiki.org/wiki/Extension:OAuth)
which is not currently in Docker Hub.
This project uses plain bot passwords for API testing.

---

Docker is fun; five stars to the team.

> "Yes, we are *very* good."<br/>
> &nbsp;&nbsp;&nbsp; – Top Gun: Maverick, community edition

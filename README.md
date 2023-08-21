# DockerWiki

This project is an implementation of the multi-container pattern outlined
in Docker Docs'
[Getting Started](https://docs.docker.com/get-started/07_multi_container/)
guide.
The audience might be developers or students learning Docker or researching
this environment for, I don't know, for the next Mars expedition.
If you want to use Docker + LAMP for business, please find similar projects
from [Bitnami](https://hub.docker.com/r/bitnami/mediawiki) or organizations
whose context includes strong security, support, and all the other things
a business needs to run.

A summary of what is here:

- `bin/actionAPI.sh`: test MediaWiki's Action API
- `bin/backrest.sh`: simple backup and restore starter kit
- `bin/cake.sh`: build and run using Docker files
- `.env`: most configuration variables
- `compose.yaml`: build and run using Compose files
- `config.yaml`: `compose.yaml` for launching from Docker Hub
- `setEnv.sh`: shortcuts to simplify development

If you source `setEnv.sh`,
```
$ source setEnv.sh
```
to setup the following aliases,
```
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

The database container is named `data` when run using Docker; it is named `wiki-data-1` when started with Docker Compose. Enter one of these names when backing up the database volume,
```
$ br --backup wiki-data-1  # dumps DB into ./all-databases.sql
```

ADD (and test) RESTORE EXAMPLE

Latest images are pushed to [Docker Hub](https://hub.docker.com/u/idave2) and no CI is configured (yet).

Docker is fun; five stars to the team.

> "Yes, we are *very* good."<br/>
> &nbsp;&nbsp;&nbsp; – Top Gun: Maverick, community edition

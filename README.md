# DockerWiki

This project is an implementation of the multi-container pattern outlined in Docker Docs'
[Getting Started](https://docs.docker.com/get-started/07_multi_container/) guide.
It has these features:
- `cake.sh`: build and run using Docker files
- `compose.yaml`: build and run using Compose files
- `backrest.sh`: simple backup and restore starter kit

The project adds container glue to generate modified images,

- idave2/mediawiki
- idave2/mariadb

then combines them on a common network when using `docker run`,
or combines them into a single *Compose project* if using `compose up`.

Latest images are pushed to [Docker Hub](https://hub.docker.com/u/idave2).

Docker is fun; five stars to the team.

> "Yes, we are *very* good."<br/>
> &nbsp;&nbsp;&nbsp; – Top Gun: Maverick, community edition

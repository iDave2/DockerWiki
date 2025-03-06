[comment]: # (Also see:)
[comment]: # (https://stackoverflow.com/a/20885980)
[comment]: # (https://stackoverflow.com/a/33433098)

# DockerWiki

This project is an implementation of the multi-container pattern outlined
in Docker Docs'
[Getting Started](https://docs.docker.com/get-started/07_multi_container/)
guide.
It targets developers and students.
For business applications, please find similar projects from
[Bitnami](https://hub.docker.com/r/bitnami/mediawiki) or organizations
whose context includes strong security, support, and all the things a
business needs to run.

## Contents
1. [Manifest](#manifest)
2. [Builds](#builds)
3. [Backups](#backups)
4. [Installers](#installers)
   1. [Web installer](#inWeb)
   2. [Command-line installer](#inCli)
   3. [Restore an image](#inRestore)
5. [Configuration](#configuration)

## Manifest <a name="manifest"></a>

A summary of what is here:

- `bin/backrest.sh`: backs up and restores wiki's

- `bin/cake.sh`: *makes* and unmakes artifacts
- `bin/configure.sh`: configures containers with project settings
- `bin/*API.sh`: test scripts for related projects
- `.env`: default configuration
- `~/.DockerWiki/config`: user configuration
- `compose.yaml`: launch instructions for `docker compose`
- `setEnv.sh`: sets up a development environment

[Somebody stop me](https://www.youtube.com/watch?v=jJLlGmXKvyo).

## Builds

When run from mariadb or mediawiki directories, `cake.sh` only builds that
image. When run from the parent of those folders &ndash; the project root
&ndash; `cake.sh` builds both images:

```bash
$ cake.sh        # create everything
$ cake.sh -cccc  # destroy everything
$ cake.sh -h     # display usage summary
```

The `--clean` option is so complex, it might function as a Turing machine:

```bash
$ cake.sh -c     # Removes build folders,
$ cake.sh -cc    # and containers and networks,
$ cake.sh -ccc   # and images,
$ cake.sh -cccc  # and volumes.
```

Build instructions were removed from `compose.yaml` when post-install steps
became complex. `docker compose` still launches DockerWiki provided it can
find the requested images locally or on the hub,

```bash
$ docker compose up -d                # create everything
$ docker compose down -v --rmi local  # destroy most stuff
```

Remember to backup important data before (accidentally) removing its volume!

## Backups

`backrest.sh` backs up and restores three items:

- MariaDB's mediawiki database;
- MediaWiki images directory tree;
- MediaWiki LocalSettings.php file.

The working directory (option `-w` or `--work-dir`) is
optional for backup but required for restore:

```bash
$ backrest.sh --backup  # -> /tmp/DockerWiki/backups/<date>/
$ backrest.sh -bw ./my-git-backups/   # -> ./my-git-backups/
$ backrest.sh -rw ./my-git-backups    # <- ./my-git-backups/
```

## Installers

In this context, *installer* refers to the method used to create MediaWiki's
initial database and runtime configuration stored in `LocalSettings.php`.
`cake.sh` offers three choices:
```bash
$ cake.sh -i web        # web-based installer
$ cake.sh --installer cli   # command-line installer (default)
$ cake.sh -i restore=my/backup  # build with restored backup
```

### Web installer <a id="inWeb" name="inWeb"></a>

The web installer presents you with a "set up the wiki" browser page,
just like a vanilla container with the hub's official MediaWiki image,
except that a big MariaDB system lurks nearby,
```bash
$ docker run --name some-mediawiki -d -p 8080:80 mediawiki
```
For web installs, MariaDB is given only a root account and no application
(mediawiki) database and user, so the MediaWiki installer needs to know
the MariaDB root password `DB_ROOT_PASSWORD`, and the MariaDB root login
must be available to the MediaWiki container (or host), so this configuration
is less secure than with `MARIADB_ROOT_HOST=localhost`.

This method offers advanced installers granular control over all aspects
of configuration (like which extensions to include).

### Command-line installer <a id="inCli" name="inCli"></a>

This method leverages built-in PHP programs to automate installation.
Configuration settings come from definitions scattered in increasing
order of precedence by files `.env`, `DW_USER_CONFIG`, and command-line
assignments.

For example, file `.env` begins with a line,

```bash
DW_HID=${DW_HID:-idave2} # Docker Hub ID
```

This bash jargon means "set DW_HID to idave2 unless it is already set."
To build images with `your_hub_id` rather than mine, you could (write your
own `.env` or) override `.env` on the command line,

```bash
$ DW_HID=your_hub_id cake.sh -i cli
```

or you could add a line to `DW_USER_CONFIG` (after learning that its
default location is `~/.DockerWiki/config`),

```bash
DW_HID=${DW_HID:-your_hub_id} # Override .env
```

`DW_USER_CONFIG` is a good place to hide secrets.

### Restoring (backups into) an image <a id="inRestore" name="inRestore"></a>

The first two installation methods create a database and local settings *after* the
images are built and running in their containers, so if these containers
(not images) were destroyed and recreated, they would again need to have
a database and local settings created.

In order for these artifacts to end up in image layers rather than volatile
container memory, we use a Dockerfile that copies them into the image from
a folder previously created by `backrest.sh` (i.e., a backup):
```bash
$ cake.sh --installer restore=./hub
```
This is how the Docker Hub images corresponding to this git repository
were created.

Also see `docker commit`, another method for creating new images from
containers.

## Configuration

Most configuration settings may be changed in DW_USER_CONFIG. Its default
location, `~/.DockerWiki/config`, can be changed in `.env`.

Given a typical DW_USER_CONFIG like this,

```bash
# DockerWiki user config overrides

DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-myPassRoot}
DB_USER_PASSWORD=${DB_USER_PASSWORD:-myPassDBA}
MW_ADMIN_PASSWORD=${MW_ADMIN_PASSWORD:-myPassAdmin}

MW_ENABLE_UPLOADS=true

# Only used by dw.sh ...
MY_BACKUP_DIR=~/Documents/Backups
```

apply these overrides to the wiki like this,

```bash
$ configure.sh --verbose
```

---

Latest images are pushed to
[Docker Hub](https://hub.docker.com/repository/docker/idave2/mediawiki/)
and no CI is configured (yet).

Docker is fun; five stars to the team.

> "Yes, we are *very* good."<br/>
> &nbsp;&nbsp;&nbsp; – Top Gun: Maverick, community edition

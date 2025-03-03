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

A summary of what is here:

- `bin/backrest.sh`: simple backup and restore starter kit
- `bin/cake.sh`: build script to *make* and unmake artifacts
- `bin/*API.sh`: test scripts for related projects
- `.env`: build and runtime configuration variables
- `compose.yaml`: launch instructions for `docker compose`
- `setEnv.sh`: shortcuts to simplify development and test

## Builds

`source setEnv.sh` for a build script that runs anywhere,
```bash
alias cake="/absolute/path/to/bin/cake.sh"
alias dc="docker compose"
```
When run from mariadb or mediawiki directories, `cake` only builds that image.
When run from the parent of those folders &ndash; the project root &ndash;
`cake` builds both images:
```bash
$ cake        # create everything
$ cake -cccc  # destroy everything
$ cake -h     # display usage summary
```
The `--clean` option is so complex, it might function as a Turing machine:
```bash
$ cake -c     # Removes build folders,
$ cake -cc    # and containers and networks,
$ cake -ccc   # and images,
$ cake -cccc  # and volumes.
```
Build instructions were removed from `compose.yaml` when post-install steps
became complex. `docker compose` still launches DockerWiki provided it can
find the requested images locally or on the hub,
```bash
$ dc up -d                # create everything
$ dc down -v --rmi local  # destroy almost everything
```
Remember to backup important data before (accidentally) removing its volume!

## Backups

`source setEnv.sh` for a backup and restore script that runs anywhere,
```bash
alias br="/absolute/path/to/bin/backrest.sh"
```
`backrest.sh` backs up and restores three items:
- MariaDB database;
- MediaWiki images directory tree;
- MediaWiki LocalSettings.php file.

The working directory (option `-w` or `--work-dir`) is
optional for backup but required for restore:
```bash
$ br -b                             # -> /tmp/DockerWiki/backup-<date>/
$ br -bw ./my-git-backups/          # -> ./my-git-backups/
$ br --restore -w ./my-git-backups  # <- ./my-git-backups/
```

# Installers

In this context, *installer* refers to the method used to create MediaWiki's
initial database and runtime configuration stored in `LocalSettings.php`.
`cake` offers three choices:
```bash
$ cake -i web                # web-based installer
$ cake --installer cli       # command-line installer (default)
$ cake -i restore=my/backup  # Restore a backrest.sh backup
```
## Web installer
The web installer presents you with a "set up the wiki" browser page,
just like a vanilla container with the hub's official mediawiki image,
except that a big MariaDB system lurks nearby,
```bash
$ docker run --name some-mediawiki -d -p 8080:80 mediawiki
```
For web installs, MariaDB is given only a root account and no application
(mediawiki) database and user, so the MediaWiki installer needs to know
the MariaDB root password (see `mariadb/root-password-file`), and the
MariaDB root login must be available to the MediaWiki container, so this
configuration is less secure than with `MARIADB_ROOT_HOST=localhost`.

This method offers advanced installers granular control over all aspects
of configuration (like which extensions to include).

## Command-line installer
This method leverages built-in PHP programs to automate installation.
Configuration settings come from `DW_` variables scattered in increasing
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
$ DW_HID=your_hub_id cake -i cli
```

or you could add a line to `DW_USER_CONFIG` (after learning that its
default location is `~/.DockerWiki/config`),

```bash
DW_HID=${DW_HID:-your_hub_id} # Override .env
```

`DW_USER_CONFIG` is a good place to hide secrets.

Finally, this command-line installer includes extensions so is relatively large.

[comment]: # (
  That's fine, Dave. Anyone using this as a template
  will eventually grok what they like and toss the rest.
  See https://stackoverflow.com/a/20885980.
)


## Restoring (backups into) an image
The first two installation methods create a database and local settings *after* the
images are built and running in their containers, so if these containers
(not images) were destroyed and recreated, they would again need to have
a database and local settings created.

In order for these artifacts to end up in image layers rather than volatile
container memory, we use a Dockerfile that copies them into the image from
a folder previously created by `backrest.sh` (i.e., a backup):
```bash
$ cake --installer restore=./hub
```
This is how the Docker Hub images corresponding to this git repository
were created.

Also see `docker commit`, another method to commit changes from a running
container into a new image.

---

Latest images are pushed to [Docker Hub](https://hub.docker.com/u/idave2) and no CI is configured (yet).

Docker is fun; five stars to the team.

> "Yes, we are *very* good."<br/>
> &nbsp;&nbsp;&nbsp; – Top Gun: Maverick, community edition

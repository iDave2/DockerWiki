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
- `config.yaml`: to be deprecated away
- `setEnv.sh`: shortcuts to simplify development and test

## Builds

`source setEnv.sh` for a build script that runs anywhere,
```bash
alias cake="/absolute/path/to/bin/cake.sh"
alias dc="docker compose"
```
When run from mariadb or mediawiki directories, `cake` only builds that image.
When run from the parent of those folders &ndash; that is, the project root
&ndash; `cake` builds both images:
```bash
$ cake      # create everything
$ cake -c   # destroy containers and images
$ cake -cc  # also remove volumes and networks
$ cake -h   # print usage summary
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

## Bash

If you are new to scripting, I strongly recommend investing a week or two
in *perl*; it will get you to Mars and back. Bash is ubiquitous so also
good to learn, here are some thoughts on its usage in this program.

When running a COMMAND, it can be tricky to keep track of three famous
items: STDOUT, STDERR, and the exit status '\$?' of last COMMAND. A nice
way to track '\$?' is to use Bash's own syntax,
```bash
if COMMANDS1; then
  COMMANDS2; # if COMMANDS1 succeeded
else
  COMMANDS3; # if COMMANDS1 failed
fi,
```
because the thing being tested in that *if condition* is precisely '\$?'.

If you don't care about the details, if you just want the program to die
when anyone's status is other than "all happy," there is the method
used in many Dockerfiles,
```bash
set -e
if COMMANDS1; then
  COMMANDS2; # if COMMANDS1 succeeded
fi
```
This causes a hard exit when COMMANDS1 fails, efficient if sometimes
difficult to debug.

If you don't care about STDOUT but want to catch errors, a brief notation
works well,
```bash
COMMANDS1 || COMMANDS3
```
A potential downside here is that STDOUT is mixed with STDERR and COMMAND3
cannot see STDERR, it can just report "something bad happened."

Helper functions in `include.sh`,
```bash
xQute2() { "$@" 2>/tmp/errFile; }
getLastError() { cat /tmp/errFile; }
```
lead to bash expressions like,
```bash
xQute2 COMMANDS1 || die "Not happy because: $(getLastError)"
```
Other interesting variations are possible.

---

Latest images are pushed to [Docker Hub](https://hub.docker.com/u/idave2) and no CI is configured (yet).

Docker is fun; five stars to the team.

> "Yes, we are *very* good."<br/>
> &nbsp;&nbsp;&nbsp; – Top Gun: Maverick, community edition

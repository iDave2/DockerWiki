# Developer Memoir

Assorted development notes for future selves.

Dave, put this on gist or erase. You could present it as little
explore & learn bitesize thoughts if it still feels helpful in a month.

## Installation

When you run the [official mediawiki image](https://hub.docker.com/_/mediawiki)
and first view it in a browser, it launches a wizard to prompt for configuration
parameters before creating its database and `LocalSettings.php` file.
This is a *web-based installation*.

In order for new users to find a ready-to-eat DockerWiki rather than being
asked to think harder (always risky), we need to somehow install MediaWiki
manually, whenever it is built. Happily, the community already has [an app
for this](https://www.mediawiki.org/wiki/Manual:Install.php):
```
  # php maintenance/install.php --env-checks
```
The challenge is to maintain an edible DockerWiki regardless of *developer's*
configuration preferences.

<details><summary>Noisy research</summary>
<p>

```bash
# Run installer.
php maintenance/install.php
  --conf=notused            # LocalSettings.php address; old, obsolete, maybe
  --confpath=notused        # ditto, maybe
  --dbgroupdefault=notused
  --dbname="$MW_DB_DATABASE"
  --dbpass=notused          # use --dbpassfile instead
  --dbpassfile="DockerWiki/dbpassfile"
  --dbpath=notused
  --dbport=notused          # only for non-mysql contexts
  --dbprefix=notused        # if many schemas in one DB
  --dbschema=notused        # only for non-mysql schemes
  --dbserver=notused        # default 'localhost', should be 'data' ?
  --dbtype=notused          # default 'mysql'
  --dbuser="$MW_DB_USER"
  --env-checks=notused      # see above, this ignores other options
  --globals                 # no value, i think; output globals when done
  --help=notused
  --installdbpass=notused   # mariadb entrypoint does this
  --installdbuser=notused   # mariadb entrypoint does this
  --lang=notused            # default 'en'
  --memory-limit=notused
  --pass=notused            # use --passfile instead
  --passfile=DockerWiki/passfile
  --profiler=notused        # default profiler output is 'text'
  --quiet=notused           # maybe used, does not take value methinks
  --scriptpath=notused      # but may need, default is '/wiki'?
  --server="http://localhost:8080" # i think? fix that hard port too.
  --skins=notused           # default 'all' but we still wanna Use 'timeless'
  --wiki=notused            # wiki ID? is this $wgSitename = "DockerWiki" ?
  --with-extensions=notused # "detect" and include extensions? meaning?
  DockerWiki
  WikiAdmin
```

</p>
</details>

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

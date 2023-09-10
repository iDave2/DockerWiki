# Developer Memoir

Assorted development notes for future selves.

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
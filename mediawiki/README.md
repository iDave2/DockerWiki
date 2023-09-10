# Developer Memoir

Assorted development notes that may be helpful in future.

## Installation

When you run the [official mediawiki image](https://hub.docker.com/_/mediawiki)
and first view it in a browser, it launches a wizard to prompt for configuration
parameters before creating its database and `LocalSettings.php` file.
This is a *web-based installation*.

In order for new users to find a ready-to-eat DockerWiki rather than being
asked to think harder (always risky), we need to somehow install MediaWiki
manually. Happily, the community already has [an app for
this](https://www.mediawiki.org/wiki/Manual:Install.php):
```
  # php maintenance/install.php --env-checks
```
The challenge is to maintain an edible DockerWiki regardless of *developer's*
configuration preferences.
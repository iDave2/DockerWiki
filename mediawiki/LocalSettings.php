<?php
# This file was automatically generated by the MediaWiki 1.39.4
# installer. If you make manual changes, please keep track in case you
# need to recreate them later.
#
# See docs/Configuration.md for all configurable settings
# and their default values, but don't forget to make changes in _this_
# file, not there.
#
# Further documentation for configuration settings may be found at:
# https://www.mediawiki.org/wiki/Manual:Configuration_settings

# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}


## Uncomment this to disable output compression
# $wgDisableOutputCompression = true;

$wgSitename = "DockerWiki";

## The URL base path to the directory containing the wiki;
## defaults for all runtime URL paths are based off of this.
## For more information on customizing the URLs
## (like /w/index.php/Page_title to /wiki/Page_title) please see:
## https://www.mediawiki.org/wiki/Manual:Short_URL
$wgScriptPath = "";

## The protocol and server name to use in fully-qualified URLs
$wgServer = "http://localhost:8080";

## The URL path to static resources (images, scripts, etc.)
$wgResourceBasePath = $wgScriptPath;

## The URL paths to the logo.  Make sure you change this from the default,
## or else you'll overwrite your logo when you upgrade!
$wgLogos = [
	'1x' => "$wgResourceBasePath/resources/assets/change-your-logo.svg",
	'icon' => "$wgResourceBasePath/resources/assets/change-your-logo.svg",
];

## UPO means: this is also a user preference option

$wgEnableEmail = false;
$wgEnableUserEmail = true; # UPO

$wgEmergencyContact = "";
$wgPasswordSender = "";

$wgEnotifUserTalk = false; # UPO
$wgEnotifWatchlist = false; # UPO
$wgEmailAuthentication = true;

## Database settings
$wgDBtype = "mysql";
$wgDBserver = "data";
$wgDBname = "mediawiki";
$wgDBuser = "wikiDBA";
$wgDBpassword = "changeThis";

# MySQL specific settings
$wgDBprefix = "";

# MySQL table options to use during installation or update
$wgDBTableOptions = "ENGINE=InnoDB, DEFAULT CHARSET=binary";

# Shared database table
# This has no effect unless $wgSharedDB is also set.
$wgSharedTables[] = "actor";

## Shared memory settings
$wgMainCacheType = CACHE_NONE;
$wgMemCachedServers = [];

## To enable image uploads, make sure the 'images' directory
## is writable, then set this to true:
$wgEnableUploads = true;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = "/usr/bin/convert";

# InstantCommons allows wiki to use images from https://commons.wikimedia.org
$wgUseInstantCommons = false;

# Periodically send a pingback to https://www.mediawiki.org/ with basic data
# about this MediaWiki instance. The Wikimedia Foundation shares this data
# with MediaWiki developers to help guide future development efforts.
$wgPingback = true;

# Site language code, should be one of the list in ./includes/languages/data/Names.php
$wgLanguageCode = "en";

# Time zone
$wgLocaltimezone = "UTC";

## Set $wgCacheDirectory to a writable directory on the web server
## to make your wiki go slightly faster. The directory should not
## be publicly accessible from the web.
#$wgCacheDirectory = "$IP/cache";

# A brash attempt to defeat Git Guardian warnings.
# $wgSecretKey = "433... hide these secret numbers...";
if (!defined('wgSecretKey')) {
  include 'includes/utils/MWCryptRand.php';
  $wgSecretKey = MWCryptRand::generateHex(64);
}

# Changing this will log out all existing sessions.
$wgAuthenticationTokenVersion = "1";

# Site upgrade key. Must be set to a string (default provided) to turn on the
# web installer while LocalSettings.php is in place
$wgUpgradeKey = "dd6c12193cb5c6b5";

## For attaching licensing metadata to pages, and displaying an
## appropriate copyright notice / icon. GNU Free Documentation
## License and Creative Commons licenses are supported so far.
$wgRightsPage = ""; # Set to the title of a wiki page that describes your license/copyright
$wgRightsUrl = "";
$wgRightsText = "";
$wgRightsIcon = "";

# Path to the GNU diff3 utility. Used for conflict resolution.
$wgDiff3 = "/usr/bin/diff3";

## Default skin: you can change the default skin. Use the internal symbolic
## names, e.g. 'vector' or 'monobook':
$wgDefaultSkin = "timeless";

# Enabled skins.
# The following skins were automatically enabled:
wfLoadSkin( 'MinervaNeue' );
wfLoadSkin( 'MonoBook' );
wfLoadSkin( 'Timeless' );
wfLoadSkin( 'Vector' );


# End of automatically generated settings.
# Add more configuration options below.

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
# These acronyms are sometimes (often) conflated online:
#
# - OATH = Open Authentication = a reference standard like TOTP or HOTP
#   for login auth'n (i.e., making sure you are in fact who you say you are).
#
# - OAuth = Open Authorization = an open standard for Access Delegation,
#   like saying who (i.e., Facebook, Google, etc.) can read your secrets.
#   "Who can access what" is auth'z, not auth'n.
#
# Also see https://en.wikipedia.org/wiki/Initiative_for_Open_Authentication.
#
# This is recommended (if client supports it)
# but not required for simple bot passwords.
wfLoadExtension('OATHAuth');

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  OATHAuth yields "Fatal exception of type Wikimedia\Rdbms\DBQueryError"
#  so try this: https://www.mediawiki.org/wiki/Topic:U26n1a1pgo0078tt.
#  Seems we are missing table 'mediawiki.oathauth_users'. Sad indeed.
#
$wgShowExceptionDetails = true;
$wgShowDBErrorBacktrace = true;
$wgShowSQLErrors = true;

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Something to peek at php environment. https://stackoverflow.com/a/9816958.
#
# echo '<pre>';
# print_r($GLOBALS);
# echo '</pre>';
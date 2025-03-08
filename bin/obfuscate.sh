#!/usr/bin/env bash
#
#  This program masks passwords and secrets in a given LocalSettings.php.
#  With the -k or --keep command-line option, the original file is kept
#  in LocalSettings.php.bak; otherwise, it is deleted.
#
#  See configure.sh for the undoing of this cryptography.
#
#  Here is an example circa March 2025,
#
#      $wgDBpassword    = "changeThis";
#      $wgSecretKey     = "<64 hex digits>";
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

ScriptDir=$(dirname -- $(realpath -- ${BASH_SOURCE[0]}))
source "${ScriptDir}/bootstrap.sh"

File='' Keep=false Stars='********' Verbose=false

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

main() {

  parseCommandLine "$@"

  test -n "$File" || usage "Specify a LocalSettings.php to encrypt"
  test -f "$File" || (echo && echo "Is '$File' a file?")

  perl -i.bak -pwe '
  s {^\s*(\$wgDBpassword)\s*=.*}    {$1 = "'$Stars'";} ;
  s {^\s*(\$wgSecretKey)\s*=.*}     {$1 = "'$Stars'";} ;
  ' $File

  $Verbose && xCute diff $File.bak $File
  $Keep || xCute rm -f $File.bak || die "Error: $(getLastError)"
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

parseCommandLine() {
  set -- $(getOpt "$@")
  while test $# -gt 0; do # https://stackoverflow.com/a/14203146
    case "$1" in
    -h | --help)
      usage
      ;;
    -k | --keep)
      Keep=true
      shift
      ;;
    -v | --verbose)
      Verbose=true
      shift
      ;;
    -* | --*)
      usage unknown option \"$1\"
      ;;
    *)
      test -n "$File" && usage "unexpected argument '$1'"
      File=$1
      shift
      ;;
    esac
  done
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

usage() {
  if [ -n "$*" ]; then
    echo -e "\n***  $@  ***" >&2
  fi
  cat >&2 <<EOT

Usage: $(basename ${BASH_SOURCE[0]}) [OPTIONS] local_settings_file

Obfuscate secrets in a given LocalSettings.php.

Options:
  -h | --help       Print this usage summary
  -k | --keep       Keep original in LocalSettings.php.bak
  -v | --verbose    Show diffs
EOT
  exit 1
}

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

main "$@"

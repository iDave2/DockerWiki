#!/usr/bin/env bash
#
#  Exploring REST alternative to legacy Action API.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Where am I?  What year is this?
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source ${SCRIPT_DIR}/include.sh

# Assorted common curl options.
CO_CORE="--no-progress-meter --show-error"

WIKI="http://localhost:8080"
API="rest.php"
WIKI_API="${WIKI}/${API}"

####-####+####-####+####-####+####-####+
#
#  Example is not the main thing in influencing others. It is the only thing.
#    -- Albert Schweitzer
#
main() {

  local cr command="curl ${CO_CORE} --request GET ${WIKI_API}"
  [ -n "$*" ] && command+="/$*"

  $TRACE
  # $(xCurl "Get some V2" "$command")
  cShow "Get some V2" "$command"
  echo $($command) | jq .
  # echo "junk: $junk"
  # | jq .
  $TRACE
  # show "Get some V2" "$command"
  # cr=$($command)
  # echo "$cr" | jq .
  # echo "$cr" | jq '.|.revisions[0:2]'
}

####-####+####-####+####-####+####-####+
#
#  Let the games begin.
#
main "$@"

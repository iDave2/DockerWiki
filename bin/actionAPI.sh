#!/usr/bin/env bash
#
#  Adapted from https://github.com/BorderCloud/bash-mediawiki/, this
#  MediaWiki API example requires 'curl' and 'jq' (a JSON processor).
#
#  Heuristic output may include Secrets so is Not Secure.
#
#  This program uses MW robots. See here to learn more,
#
#    https://www.mediawiki.org/wiki/Manual:Creating_a_bot
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
set -uo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source ${SCRIPT_DIR}/include.sh

# Tokens are required for most write operations.
# LOGIN_TOKEN=
EDIT_TOKEN=

DASHES='-----'

# Bot account and password.
BOT_NAME="WikiAdmin@Robot"
BOT_PASS="aj5t487olv708lveukaheqj5etqf5e1h"

####-####+####-####+####-####+####-####+####-####+####-####+####-####+####
#
#  Whether we use 'localhost' or '127.0.0.1' for SERVER hostname, curl
#  always starts with this disturbing message:
#
#    * URL rejected: Bad hostname
#    * Closing connection -1
#    curl: (3) URL rejected: Bad hostname
#    *   Trying 127.0.0.1:8080...
#    * Connected to 127.0.0.1 (127.0.0.1) port 8080 (#0)
#
#  Leaving SERVER as is, debug this another day.
#
SERVER="http://localhost:8080"
API=api.php
WIKI_API="${SERVER}/${API}"

WORK_DIR="/tmp/wiki"
[ -d "$WORK_DIR" ] && rm -f ${WORK_DIR}/{cj,tk}'*' || mkdir "$WORK_DIR"

FORM=() # See makeForm.

PAGE="Title of an article"
PAGE_TEXT="{{nocat|2017|01|31}}-"

IMAGE_DIR="${WORK_DIR}/images"
[ -d "$IMAGE_DIR" ] || mkdir "$IMAGE_DIR"

FILE_URL=https://www.mediawiki.org/static/images/project-logos/mediawikiwiki.png
FILE_PATH="${IMAGE_DIR}/mediawikiwiki.png"
FILE_NAME=myMediaWikiWiki.png
FILE_COMMENT="image file comment"
FILE_TEXT="image file text"

#
cookie_jar="${WORK_DIR}/cjInit"
[ -e "$cookie_jar" ] && rm $cookie_jar
cookie_jar_login="${WORK_DIR}/cjLogin"
[ -e "$cookie_jar_login" ] && rm $cookie_jar_login

####-####+
#
#  --compressed: not needed for local testing
#  --keepalive: enabled by default
#  --user-agent curl/8.1.2: default beats "Curl Shell Script"
#
#  --form: used with POST, not GET
#
hCore=(
  --keepalive-time 10 # default 60 seconds
  --location          # -L, follow redirects
  --no-progress-meter # switch off progress meter only
  -H "Accept-Language: en-us"
)
hRetry=( # used by getLoginToken() & showBotRights()
  --retry 2       # default is to never retry
  --retry-delay 5 # disables exponential backoff algorithm
)

# echo "hCore is ${hCore[*]}, hRetry is ${hRetry[@]}"
# echo BYE $LINENO && exit $LINENO

####-####+####-####+####-####+####-####+
#
#  Exit area for show stoppers.
#
abort() {
  local exitStatus=$1
  shift
  echo && echo '***' $(basename ${BASH_SOURCE[0]}): "$*" - aborting 1>&2
  exit $exitStatus
}

####-####+####-####+####-####+####-####+
#
#  Banners help with reading output and recalling what life means.
#
banner() {
  local method=${1:-''} url=${2:-''}
  cat <<-END


####-####+####-####+
#
#  ${FUNCNAME[1]}(): $method
END
  [ -n "$url" ] && echo "#  $url"
}

####-####+####-####+####-####+####-####+
#
#  Append text to a given page. Create page if it does not exist.
#
edit() {

  local token
  getEditToken token || abort 2 "getEditToken() failed"

  local query=$(qURL "action=edit" "format=json" "title=${PAGE}" "appendtext=${PAGE_TEXT}" "token=${token}")
  banner "POST $API?$query" # Something readable for POST operations.

  makeForm "action=edit" "title=${PAGE}" "appendtext=${PAGE_TEXT}" "token=${token}" "format=json"

  # local cr=$(curl "${hCore[@]}" --cookie $cookie_jar_login "${FORM[@]}" "${WIKI_API}")
  xCute12 curl "${hCore[@]}" --cookie $cookie_jar_login "${FORM[@]}" "${WIKI_API}" ||
    die "Edit failed: $(getLastError)"
  local cr=$(getLastOutput)

  echo "$cr" | jq .

  [ "$(echo $cr | jq '.error')" != "null" ] && return 2
  [ "$(echo $cr | jq '.warnings')" != "null" ] && return 1
  [ "$(echo $cr | jq '.edit.result')" == *"Success"* ] && return 0
  return 42 # intentional failure test, evidently...
}

####-####+####-####+####-####+####-####+
#
#  Get an Edit Token (a csrf token) for subsequent writes.
#
getEditToken() {

  local __return=$1
  eval $__return="''"

  local query=$(qURL action=query meta=tokens format=json)
  banner "GET $API?$query"

  local cr=$(curl --no-progress-meter --show-error \
    --location --compressed \
    --keepalive-time 60 \
    --cookie $cookie_jar_login \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --request "GET" "${WIKI_API}?${query}")

  echo "$cr" | jq .

  echo "$cr" >${WORK_DIR}/tkEdit.json
  local __token=$(jq --raw-output '.query.tokens.csrftoken' ${WORK_DIR}/tkEdit.json)
  eval $__return="'$__token'"

  # Remove carriage return!
  [[ "$__token" == *"+\\"* ]] && return 0 || return 1
}

####-####+####-####+####-####+####-####+
#
#  Robot login requires a login token. Also see,
#  https://www.linuxjournal.com/content/return-values-bash-functions
#
getLoginToken() {

  local __return=$1
  eval $__return="''"

  local query=$(qURL action=query meta=tokens type=login format=json)
  banner "GET $API?$query"

  local cr=$(curl \
    --no-progress-meter --show-error \
    --location --compressed \
    --retry 2 --retry-delay 5 --keepalive-time 60 \
    --cookie-jar $cookie_jar \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --request "GET" "${WIKI_API}?${query}")

  echo "$cr" | jq .

  # highlight jq reading from a file
  local file="${WORK_DIR}/tkLogin.json"
  echo "$cr" >${file}
  local __token=$(jq --raw-output '.query.tokens.logintoken' ${file})

  # set return value and status code
  eval $__return="'$__token'"
  [ "$__token" == "null" ] && return 1 || return 0
}

####-####+####-####+####-####+####-####+
#
#  Login the bot.
#
login() {

  local token=''
  getLoginToken token || abort 2 "getLoginToken() failed"

  # Format POST as URL query for easier output representation.
  query=$(qURL action=login lgname=${BOT_NAME} lgpassword=${BOT_PASS} lgtoken=${token} format=json)
  banner "POST $API?$query"

  local cr=$(curl \
    --no-progress-meter --show-error \
    --location --compressed \
    --keepalive-time 60 \
    --cookie $cookie_jar --cookie-jar $cookie_jar_login \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --form "action=login" \
    --form "lgname=${BOT_NAME}" \
    --form "lgpassword=${BOT_PASS}" \
    --form "lgtoken=${token}" \
    --form "format=json" \
    --request "POST" "${WIKI_API}")

  echo "$cr" | jq .

  local status=$(echo $cr | jq '.login.result')
  [[ $status == *"Success"* ]] && return 0 || return 2
}

####-####+####-####+####-####+####-####+
#
#  In the beginning, there was main().
#
main() {

  banner "UTF8 check: ☠ (<- is that a padlock?)"

  login || abort 2 "login() failed"

  showBotRights
  case $? in
  0) ;;
  1) echo "showBotRights() has warnings, ignoring" ;;
  *) abort 2 "showBotRights() failed" ;;
  esac

  edit || abort 2 "edit() failed"

  # upload() works but is disabled as it may fill mw's image archive with
  # redundant files if run repeatedly.
  # upload || abort 2 "upload() failed"

  # Delete something? Not today.
  # See https://www.mediawiki.org/wiki/Manual:Image_administration#Deletion_of_images

  echo && echo '### END OF TEST'
}

####-####+####-####+####-####+####-####+
#
#  For easier reading, copies args into FORM array with each preceeded by
#  "--form". Then give "${FORM[@]}" (with quotes) to curl during POST. E.g.,
#
#    makeForm "action=edit" "title=Title has spaces" "text=more space"
#
makeForm() {
  FORM=()
  for option in "$@"; do
    FORM+=(--form "$option")
  done
}
####-####+####-####+####-####+####-####+
#
#  For ease reading URL's, "qURL n1=v1 n2=v2  n3=v3" --> "n1=v1&n2=v2&n3=v3"
#
#  (Simply another 'echo' seems to remove extra white, another bash interpolation..)
#
qURL() { # https://stackoverflow.com/a/12973694
  # echo "$@" | xargs | tr ' ' '&'
  join '&' "$@"
}

####-####+####-####+####-####+####-####+
#
#  Display bot rights. Robots have rights too...
#
showBotRights() {

  local query=$(qURL action=query meta=userinfo 'uiprop=groups|realname|Xrights' format=json)
  banner "GET $API?$query"

  local cr=$(curl \
    --no-progress-meter --show-error \
    --location --compressed \
    --retry 2 --retry-delay 5 --keepalive-time 60 \
    --cookie $cookie_jar_login \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --request "GET" "${WIKI_API}?${query}")

  echo "$cr" | jq .
}

####-####+####-####+####-####+####-####+
#
#  Demonstrate uploading an image.
#
upload() {

  local token cr

  # download test image if not already here
  if [ ! -e "$FILE_PATH" ]; then
    banner "GET $FILE_URL"
    cr=$(curl --no-progress-meter --show-error "$FILE_URL" --output "$FILE_PATH")
  fi
  echo "$cr" | jq .

  query=$(qURL action=upload format=json filename="$FILE_NAME" token="$EDIT_TOKEN")
  banner "POST $API?$query"

  # Re --header "Expect:", from curl man page, "Remove an internal header
  # by giving a replacement without content on the right side of the colon,
  # as in: -H "Host:". Is curl's default "Expect: 100-continue"?
  cr=$(curl --no-progress-meter --show-error \
    --location --no-compressed \
    --keepalive-time 60 \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --header "Expect:" \
    --cookie $cookie_jar_login \
    --form "action=upload" --form "format=json" --form "ignorewarnings=yes" \
    --form "filename=${FILE_NAME}" --form "comment=${FILE_COMMENT}" \
    --form "text=${FILE_TEXT}" --form "file=@${FILE_PATH}" \
    --form "token=${EDIT_TOKEN}" \
    --request "POST" "${WIKI_API}")

  echo "$cr" | jq .
}

####-####+####-####+####-####+####-####+
#
#  Capture bash with a compelling story.
#
main "$@"

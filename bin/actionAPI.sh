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

# Tokens are required for most write operations.
# LOGIN_TOKEN=
EDIT_TOKEN=

DASHES='-----'

# The following credentials are wired into initial database so that
# test scripts work "out of the box." Not even ChatGPT could figure
# out how to create and destroy bots locally with the API. ;)
BOT_NAME="WikiAdmin@Robot"
BOT_PASS="8gskqe10rgglcocrdt89pqvq6sshkd42"

WIKI="http://localhost:8080"
API=api.php
WIKI_API="${WIKI}/${API}"

WORK_DIR="/tmp/wiki"
[ -d "$WORK_DIR" ] && rm -f ${WORK_DIR}/{cj,tk}'*' || mkdir "$WORK_DIR"

PAGE="Title of an article"
PAGE_TEXT="{{nocat|2017|01|31}} "

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
  cat <<-END


####-####+####-####+
#
#  ${FUNCNAME[1]}(): $1
END
  [ -n "$2" ] && echo "#  $2"
}

####-####+####-####+####-####+####-####+
#
#  Append text to a given page. Create page if it does not exist.
#
edit() {

  local token
  getEditToken token || abort 2 "getEditToken() failed"

  # Represent POST as URL query for ease of reading.
  local query=$(qURL action=edit format=json title="${PAGE}" appendtext="${PAGE_TEXT}" token="${token}")
  banner "POST $API?$query"

  local cr=$(curl --no-progress-meter --show-error \
    --location --compressed \
    --keepalive-time 60 \
    --cookie $cookie_jar_login \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --form "action=edit" \
    --form "format=json" \
    --form "title=${PAGE}" \
    --form "appendtext=${PAGE_TEXT}" \
    --form "token=${token}" \
    --request "POST" "${WIKI_API}")

  echo "$cr" | jq .

  [ "$(echo $cr | jq '.error')" != "null" ] && return 2
  [ "$(echo $cr | jq '.warnings')" != "null" ] && return 1
  [ "$(echo $cr | jq '.edit.result')" == *"Success"* ] && return 0
  return 42
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
#  For ease reading URL's, "qURL n1=v1 n2=v2  n3=v3" --> "n1=v1&n2=v2&n3=v3"
#
qURL() { # https://stackoverflow.com/a/12973694
  echo "$@" | xargs | tr ' ' '&'
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

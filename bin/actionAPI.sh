#!/usr/bin/env bash
#
#  Adapted from https://github.com/BorderCloud/bash-mediawiki/, this
#  MediaWiki API example requires 'curl' and 'jq' (a JSON processor).
#
#  Heuristic output may include Secrets so is Not Secure.
#
#  Thanks, Mr. & Ms. Cloud!
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

#  KEEP BUT ADD YOUR CONTEXT ? SAY SOMETHING ABOUT DANGEROUS ROBOTS.
#
# You can create a new bot with this command:
#
# php maintenance/createBotPassword.php --grants \
#   basic,createeditmovepage,editdata,delete,editpage,uploadeditmovefile,uploadfile,highvolume \
#     --appid mediawiki1 UserData ff38s9u4feh07vjs2s6t88dh2pv5cfgv
#
# You can login in using username:'UserData@mediawiki1' and
# password:'ff38s9u4feh07vjs2s6t88dh2pv5cfgv'.

# Tokens are required for most write operations.
LOGIN_TOKEN=
EDIT_TOKEN=

# USERNAME="UserData@mediawiki1"
# USERPASS="ff38s9u4feh07vjs2s6t88dh2pv5cfgv"
USERNAME="WikiAdmin@Robot"
USERPASS="sdkij9pu5lsr9q1inpvkml4bh7q6ro5h"
WIKI="http://localhost:8080"
# WIKI_API="http://serverdev-mediawiki2/w/api.php"
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

cookie_jar="${WORK_DIR}/cjInit"
[ -e "$cookie_jar" ] && rm $cookie_jar
cookie_jar_login="${WORK_DIR}/cjLogin"
[ -e "$cookie_jar_login" ] && rm $cookie_jar_login

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
#  Append text to a given page. Create page if it does not already exist.
#
edit() {

  # Output banners represent both POST and GET requests as URL queries
  # since the notation is compact if technically incorrect.
  query=$(qURL action=edit format=json "title=${PAGE}" "appendtext=${PAGE_TEXT}" "token=${EDIT_TOKEN}")
  banner "POST $API?$query"

  CR=$(curl --no-progress-meter --show-error \
    --location --compressed \
    --keepalive-time 60 \
    --cookie $cookie_jar_login \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --form "action=edit" \
    --form "format=json" \
    --form "title=${PAGE}" \
    --form "appendtext=${PAGE_TEXT}" \
    --form "token=${EDIT_TOKEN}" \
    --request "POST" "${WIKI_API}")

  echo "$CR" | jq .
}

####-####+####-####+####-####+####-####+
#
#  Get an Edit Token (a csrf token) for subsequent writes.
#
getEditToken() {

  query=$(qURL action=query meta=tokens format=json)
  banner "GET $API?$query"

  CR=$(curl --no-progress-meter --show-error \
    --location --compressed \
    --keepalive-time 60 \
    --cookie $cookie_jar_login \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --request "GET" "${WIKI_API}?${query}")

  echo "$CR" | jq .

  # Border family highlights cool features of 'jq' tool...
  echo "$CR" >${WORK_DIR}/tkEdit.json
  EDIT_TOKEN=$(jq --raw-output '.query.tokens.csrftoken' ${WORK_DIR}/tkEdit.json)

  # Remove carriage return!
  if [[ $EDIT_TOKEN == *"+\\"* ]]; then
    true # echo "Edit token is: $EDIT_TOKEN"
  else
    echo "Edit token not set."
    return 1
  fi
}

####-####+####-####+####-####+####-####+
#
#  Login, part 1: retrieve a login token.
#
getLoginToken() {

  query=$(qURL action=query meta=tokens type=login format=json)
  banner "GET $API?$query"

  # CR=$(curl -S \
  CR=$(curl --no-progress-meter --show-error \
    --location --compressed \
    --retry 2 --retry-delay 5 --keepalive-time 60 \
    --cookie-jar $cookie_jar \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --request "GET" "${WIKI_API}?${query}")

  echo "$CR" | jq .

  file="${WORK_DIR}/tkLogin.json"
  echo "$CR" >${file}
  LOGIN_TOKEN=$(jq --raw-output '.query.tokens.logintoken' ${file})

  if [ "$LOGIN_TOKEN" == "null" ]; then
    echo "Getting a login token failed."
    return 1
  else
    true # echo "Login token is $LOGIN_TOKEN"
    # echo "-----"
  fi

  return 0
}

####-####+####-####+####-####+####-####+
#
#  Login, part 2: login the bot.
#
login() {

  args="action=login lgname=${USERNAME} lgpassword=${USERPASS} lgtoken=${LOGIN_TOKEN} format=json"

  # $form does not work in curl args but, fwiw,
  form=$(qForm $args)
  # echo '***' form: $form.

  # Format as URL query for easier output notation.
  query=$(qURL $args)
  banner "POST $API?$query"

  CR=$(curl --no-progress-meter --show-error \
    --location --compressed \
    --keepalive-time 60 \
    --cookie $cookie_jar --cookie-jar $cookie_jar_login \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --form "action=login" \
    --form "lgname=${USERNAME}" \
    --form "lgpassword=${USERPASS}" \
    --form "lgtoken=${LOGIN_TOKEN}" \
    --form "format=json" \
    --request "POST" "${WIKI_API}")

  echo "$CR" | jq .

  STATUS=$(echo $CR | jq '.login.result')
  if [[ $STATUS == *"Success"* ]]; then
    true # echo "Successfully logged in as $USERNAME, STATUS is $STATUS."
    # echo "-----"
  else
    echo "Unable to login, is logintoken ${LOGIN_TOKEN} correct?"
    return 1
  fi
}

####-####+####-####+####-####+####-####+
#
#  In the beginning, there was main().
#
main() {
  banner "UTF8 check: ☠ (<- is that a padlock?)"
  getLoginToken
  login
  showBotRights
  getEditToken
  edit
  upload
  # Delete something? This looks trickier.
  # See https://www.mediawiki.org/wiki/Manual:Image_administration#Deletion_of_images
  echo && echo '###' END OF TEST
}

####-####+####-####+####-####+####-####+
#
#  For ease reading form's, $(qForm n1=v1 n2=v2 n3=v3) --> --form "n1=v1" --form "n2=v2" ...
#
qForm() {
  form=()
  for arg; do
    form+=("--form \"$arg\"")
  done
  echo "${form[@]}"
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
#  Display bot rights. Robots have rights too. Dammit.
#
showBotRights() {

  query=$(qURL action=query meta=userinfo 'uiprop=groups|realname|rights' format=json)
  banner "GET $API?$query"

  CR=$(curl --no-progress-meter --show-error \
    --location --compressed \
    --retry 2 --retry-delay 5 --keepalive-time 60 \
    --cookie $cookie_jar_login \
    --user-agent "Curl Shell Script" \
    --header "Accept-Language: en-us" --header "Connection: keep-alive" \
    --request "GET" "${WIKI_API}?${query}")

  echo "$CR" | jq .

}

####-####+####-####+####-####+####-####+
#
#  Demonstrate uploading an image.
#
upload() {

  local cr

  if [ ! -e "$FILE_PATH" ]; then
    banner "GET $FILE_URL"
    cr=$(curl --no-progress-meter --show-error "$FILE_URL" --output "$FILE_PATH")
  fi
  echo "$cr" | jq .

  query=$(qURL action=upload format=json "filename=$FILE_NAME" "token=$EDIT_TOKEN")
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

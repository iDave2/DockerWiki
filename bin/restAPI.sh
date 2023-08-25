#!/usr/bin/env bash
#
#  Exploring REST alternatives to legacy Action API.
#
#  "At rest, however, in the middle of everything is the sun."
#     -- Nicolaus Copernicus
#
#  Best listening: Ramin Djawadi, https://www.youtube.com/watch?v=6Bj5uyDe-hM
#
#  MW wants a cool user agent for botwork.
#  https://meta.wikimedia.org/wiki/User-Agent_policy
#
#    "The generic format is <client name>/<version> (<contact information>)
#       <library/framework name>/<version> [<library name>/<version> ...].
#     Parts that are not applicable can be omitted."
#
#  User-Agent: CoolBot/0.0 (https://example.org/coolbot/; coolbot@example.org) generic-library/0.0
#  User-Agent: "Curly Shell Script" (http://localhost:8080/index.php/User:WikiAdmin)
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Where am I? What year is this?
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source ${SCRIPT_DIR}/include.sh # https://stackoverflow.com/a/246128

# Local endpoint.
WIKI="http://localhost:8080"
API="rest.php/v1"
WIKI_API="${WIKI}/${API}"

# Reusable chunks of Curl Options.
# CO_CORE="--no-progress-meter --show-error"
CO_CORE='-Ss'

# Sample page for testing REST API.
#PAGE_TITLE='Sleep Study'
PAGE_TITLE='Main Page'
read -r -d '' PAGE_SOURCE <<'EOF' # https://stackoverflow.com/a/1655389
Lorem ipsum *ipsum* blee,
Foorem mopsum *blipsun* glee.
EOF
PAGE_EDIT='Please do not hit Reply-All.'

####-####+####-####+####-####+####-####+
#
#  Example is not the main thing in influencing others; it is the only thing.
#    -- Albert Schweitzer
#
main() {

  # Append any user query, like "v1/page/Earth," to the URL.
  local command="curl ${CO_CORE} --request GET ${WIKI_API}"
  [ -n "$*" ] && command+="/$*"

  echo "PAGE_TITLE = '$PAGE_TITLE'"
  echo "PAGE_SOURCE = '$PAGE_SOURCE'"
  echo "PAGE_EDIT = '$PAGE_EDIT'"

  searchPage "$PAGE_TITLE"

  # cShow "REST a bit" "$command"
  # local cr=$($command)
  # echo "$cr" | jq . # | head -20 && echo '---' && echo '}'
}

####-####+####-####+####-####+####-####+
#
#  POST /page - Create a new page
#
pageCreate() {
  # https://www.mediawiki.org/wiki/API:REST_API/Reference#Create_page
  curl -X POST ${WIKI_API}/v1/page \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    --data '{ \
      "source": "Hello, world!", \
      "title": "User:WikiAdmin/Sandbox", \
      "comment": "Creating a test page with the REST API" \
    }'
}

####-####+####-####+####-####+####-####+
#
#  GET /page/{title}/bare - Get page object with "html_url"
#  https://www.mediawiki.org/wiki/API:REST_API/Reference#Get_page
#
pageGet() {
  # curl $CO_CORE "${WIKI_API}/v1/page/Main_Page/bare" | jq .
  curl -Ss "http://localhost:8080/rest.php/v1/page/Main_Page/bare" | jq .
}

####-####+####-####+####-####+####-####+
#
#  GET /page/{title}/history - Get page history
#  https://www.mediawiki.org/wiki/API:REST_API/Reference#Get_page_history
#
pageGetHistory() {
  # curl $CO_CORE "${WIKI_API}/v1/page/Main_Page/history" | jq .
  curl -Ss "http://localhost:8080/rest.php/v1/page/Main_Page/history" | jq .
}

####-####+####-####+####-####+####-####+
#
#  GET /page/{title} - Get page object with "source" (usually wikitext)
#  https://www.mediawiki.org/wiki/API:REST_API/Reference#Get_page_source
#
pageGetSource() {
  # curl $CO_CORE "${WIKI_API}/v1/page/Main_Page" | jq .
  curl -Ss "http://localhost:8080/rest.php/v1/page/Main_Page" | jq .
}

####-####+####-####+####-####+####-####+
#
#  PUT /page/{title} - Update a page
#
pageUpdate() {
  # https://www.mediawiki.org/wiki/API:REST_API/Reference#Update_page
  curl -X PUT ${WIKI_API}/v1/page/WikiAdmin:Sandbox \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    --data '{ \
      "source": "Hello, world!", \
      "comment": "Testing out the REST API", \
      "latest": {\
        "id": 555555555 \
      } \
    }'
}

####-####+####-####+####-####+####-####+
#
#  GET /search/page? - Search for page(s)
#
#  https://www.mediawiki.org/wiki/API:REST_API/Reference#Search_pages
#
searchPage() {
  # local title=$1
  local title=$(echo $1 | tr ' ' '%20')
  echo "title => '$title'"
  # local key=$(echo $title | tr ' ' '_')
  # echo "*** key = '$key'"
  # local cr=$(curl -sS ${WIKI_API}/search/page?q=${key}&limit=1)
  local command="curl -sS ${WIKI_API}/search/page?q=$title&limit=1"
  cShow "Search for page '$title'" "$command"
  local cr=$($command)
  echo $cr | jq .
}

####-####+####-####+####-####+####-####+
#
#  Let the games begin.
#
main "$@"

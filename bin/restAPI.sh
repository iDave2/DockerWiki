#!/usr/bin/env bash
#
#  Exploring REST alternatives to legacy Action API.
#
#  "At rest, however, in the middle of everything is the sun."
#     -- Nicolaus Copernicus
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

# Where am I? What year is this?
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source ${SCRIPT_DIR}/include.sh # https://stackoverflow.com/a/246128

# Local endpoint.
WIKI="http://localhost:8080"
API="rest.php"
WIKI_API="${WIKI}/${API}"

# Reusable chunks of Curl Options.
# CO_CORE="--no-progress-meter --show-error"
CO_CORE='-Ss'

####-####+####-####+####-####+####-####+
#
#  Example is not the main thing in influencing others.
#  It is the only thing.
#    -- Albert Schweitzer
#
main() {

  # Append any user query, like "v1/page/Earth," to the URL.
  local command="curl ${CO_CORE} --request GET ${WIKI_API}"
  [ -n "$*" ] && command+="/$*"

  # These phrases (may need quoting) worked in '$ restAPI.sh <phrase>'
  #
  # The following formulas are written as "METHOD ROUTE" where method is
  # GET, PUT, POST, UPDATE and ROUTEs like '/page' become 'v1/page' with
  # our current choice of ${WIKI_API}.
  #
  # ---- Create page ----
  #  POST /page
  #
  #   v1/page/Main_Page         (return Main_Page wikitext)
  #   v1/page/Main_Page/history (returns full Main_Page history)
  #   v1/search/page?q=Main_Page&limit=1" (returns nothing)
  #   v1/search/page?q=main     (returns Main_Page)
  #   v1/search/page?q=page     (same, returns Main_Page)
  #   v1/search/page?q=hondas   (returns "Hondas" and "Main Page")
  #   v1/page/Hondas            (returns "Hondas" wikitext or "source")
  #   v1/search/page?q=*        (returns nothing)
  #
  #  *v1/page/{title}           (returns page object w/"source" as wikitext)
  #   v1/page/{title}/with_html (like * but w/"html" instead of "source")
  #   v1/page/{title}/bare      (like * but w/"html_url" -> [/html route] instead of "source")
  #   v1/page/{title}/html      (raw html, do not try to jq!)
  #   v1/page/{title}/links/language (zip here)
  #   v1/page/{title}/links/media (lots from mediawiki, nothing on Main_Page?)
  #

  cShow "REST a bit" "$command"
  local cr=$($command)
  echo "$cr" | jq . # | head -20 && echo '---' && echo '}'
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
#  GET /page/{title}/bare - Get page object w/"html_url" replacing "source"
#
pageGet() {
  # https://www.mediawiki.org/wiki/API:REST_API/Reference#Get_page
  # curl $CO_CORE "${WIKI_API}/v1/page/Main_Page/bare" | jq .
  curl -Ss "http://localhost:8080/rest.php/v1/page/Main_Page/bare" | jq .
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
#  Let the games begin.
#
main "$@"
